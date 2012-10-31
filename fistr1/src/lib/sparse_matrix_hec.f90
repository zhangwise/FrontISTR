!======================================================================!
!                                                                      !
! Software Name : FrontISTR Ver. 3.2                                   !
!                                                                      !
!      Module Name : lib                                               !
!                                                                      !
!            Written by K. Goto (VINAS)                                !
!                                                                      !
!      Contact address :  IIS,The University of Tokyo, CISS            !
!                                                                      !
!      "Structural Analysis for Large Scale Assembly"                  !
!                                                                      !
!======================================================================!
!> This module provides conversion routines between HEC data structure
!! and DOF based sparse matrix structure (CSR/COO)
module m_sparse_matrix_hec
  use hecmw
  use m_fstr
  use m_sparse_matrix
  implicit none

  private

  public :: sparse_matrix_hec_init_prof
  public :: sparse_matrix_hec_set_conv_ext
  public :: sparse_matrix_hec_set_vals
  public :: sparse_matrix_hec_set_rhs
  public :: sparse_matrix_hec_get_rhs

contains

  !!! public subroutines

  subroutine sparse_matrix_hec_init_prof(spMAT, hecMAT, hecMESH)
    type (sparse_matrix), intent(inout) :: spMAT
    type (hecmwST_matrix), intent(in) :: hecMAT
    type (hecmwST_local_mesh), intent(in) :: hecMESH
    integer(kind=kint) :: ndof, ndof2, N_loc, NL, NU, NZ
    ndof=hecMAT%NDOF; ndof2=ndof*ndof
    N_loc=hecMAT%N*ndof
    if (sparse_matrix_is_sym(spMAT)) then
       NU=hecMAT%indexU(hecMAT%N)
       NZ=hecMAT%N*(ndof2+ndof)/2+NU*ndof2
    else
       NL=hecMAT%indexL(hecMAT%N)
       NU=hecMAT%indexU(hecMAT%N)
       NZ=(hecMAT%N+NU+NL)*ndof2
    endif
    call sparse_matrix_init(spMAT, N_loc, NZ)
    call sparse_matrix_hec_set_conv_ext(spMAT, hecMESH, hecMAT%NDOF)
    spMAT%timelog = hecMAT%Iarray(22)
    call sparse_matrix_hec_set_prof(spMAT, hecMAT)
  end subroutine sparse_matrix_hec_init_prof

  subroutine sparse_matrix_hec_set_conv_ext(spMAT, hecMESH, ndof)
    type(sparse_matrix), intent(inout) :: spMAT
    type (hecmwST_local_mesh), intent(in) :: hecMESH
    integer(kind=kint), intent(in) :: ndof
    integer(kind=kint) :: n_export,n_import,i,j,is,ie,len,nn_external,id,i0,ierr
    integer(kind=kint), allocatable :: export_item_dof(:), import_item_dof(:)
    integer(kind=kint), allocatable :: send_request(:), recv_request(:)
    integer(kind=kint), allocatable :: send_status(:,:), recv_status(:,:)
    ! COMMUNICATE NUMBERING
    if (hecMESH%n_neighbor_pe==0) return
    allocate(send_request(hecMESH%n_neighbor_pe), &
         recv_request(hecMESH%n_neighbor_pe), &
         send_status(HECMW_STATUS_SIZE, hecMESH%n_neighbor_pe), &
         recv_status(HECMW_STATUS_SIZE, hecMESH%n_neighbor_pe), stat=ierr)
    if (ierr /= 0) then
      write(*,*) " Allocation error, [send,recv]_[request,status]"
      call hecmw_abort(hecmw_comm_get_comm())
    endif
    ! send export list
    n_export = hecMESH%export_index(hecMESH%n_neighbor_pe)
    allocate(export_item_dof(n_export*ndof), stat=ierr)
    if (ierr /= 0) then
      write(*,*) " Allocation error, export_item_dof"
      call hecmw_abort(hecmw_comm_get_comm())
    endif
    do i=1,n_export
       do j=1,ndof
          export_item_dof(ndof*(i-1)+j)= &
               spMAT%OFFSET+ndof*(hecMESH%export_item(i)-1)+j
       enddo
    enddo
    do i=1,hecMESH%n_neighbor_pe
       is=ndof*hecMESH%export_index(i-1)+1
       ie=ndof*hecMESH%export_index(i)
       len=ie-is+1
       call HECMW_Isend_INT(export_item_dof(is:ie), len, &
            hecMESH%neighbor_pe(i), 0, hecmw_comm_get_comm(), &
            send_request(i))
    enddo
    ! receive import list
    n_import = hecMESH%import_index(hecMESH%n_neighbor_pe)
    allocate(import_item_dof(n_import*ndof), stat=ierr)
    if (ierr /= 0) then
      write(*,*) " Allocation error, import_item_dof"
      call hecmw_abort(hecmw_comm_get_comm())
    endif
    do i=1,hecMESH%n_neighbor_pe
       is=ndof*hecMESH%import_index(i-1)+1
       ie=ndof*hecMESH%import_index(i)
       len=ie-is+1
       call HECMW_Irecv_INT(import_item_dof(is:ie), len, &
            hecMESH%neighbor_pe(i), 0, hecmw_comm_get_comm(), &
            recv_request(i))
    enddo
    ! waitall
    call HECMW_Waitall(hecMESH%n_neighbor_pe, send_request, send_status)
    call HECMW_Waitall(hecMESH%n_neighbor_pe, recv_request, recv_status)
    ! dealloc
    deallocate(export_item_dof)
    deallocate(send_request, recv_request, send_status, recv_status)
    ! create conversion list
    nn_external = hecMESH%n_node - hecMESH%nn_internal
    allocate(spMAT%conv_ext(nn_external*ndof))
    if (ierr /= 0) then
      write(*,*) " Allocation error, spMAT%conv_ext"
      call hecmw_abort(hecmw_comm_get_comm())
    endif
    do i=1,n_import
       id=hecMESH%import_item(i)-hecMESH%nn_internal
       i0=ndof*(id-1)
       do j=1,ndof
          spMAT%conv_ext(i0+j)=import_item_dof(ndof*(i-1)+j)
       enddo
    enddo
    ! dealloc
    deallocate(import_item_dof)
  end subroutine sparse_matrix_hec_set_conv_ext

  subroutine sparse_matrix_hec_set_prof(spMAT, hecMAT)
    type(sparse_matrix), intent(inout) :: spMAT
    type(hecmwST_matrix), intent(in) :: hecMAT
    integer(kind=kint) :: ndof, ndof2
    integer(kind=kint) :: m, i, idof, i0, ii, ls, le, l, j, j0, jdof, jdofs
    !integer(kind=kint) :: offset_l, offset_d, offset_u
    ! CONVERT TO CSR or COO STYLE
    ndof=hecMAT%NDOF; ndof2=ndof*ndof
    m=1
    do i=1,hecMAT%N
       do idof=1,ndof
          i0=spMAT%OFFSET+ndof*(i-1)
          ii=i0+idof
          if (spMAT%type==SPARSE_MATRIX_TYPE_CSR) spMAT%IRN(ii-spMAT%OFFSET)=m
          ! Lower
          if (.not. sparse_matrix_is_sym(spMAT)) then
             ls=hecMAT%indexL(i-1)+1
             le=hecMAT%indexL(i)
             do l=ls,le
                j=hecMAT%itemL(l)
                !if (j <= hecMAT%N) then
                j0=spMAT%OFFSET+ndof*(j-1)
                !else
                !   j0=spMAT%conv_ext(ndof*(j-hecMAT%N))-ndof
                !endif
                !offset_l=ndof2*(l-1)+ndof*(idof-1)
                do jdof=1,ndof
                   if (spMAT%type==SPARSE_MATRIX_TYPE_COO) spMAT%IRN(m)=ii
                   spMAT%JCN(m)=j0+jdof
                   !spMAT%A(m)=hecMAT%AL(offset_l+jdof)
                   m=m+1
                enddo
             enddo
          endif
          ! Diag
          !offset_d=ndof2*(i-1)+ndof*(idof-1)
          if (sparse_matrix_is_sym(spMAT)) then; jdofs=idof; else; jdofs=1; endif
          do jdof=jdofs,ndof
             if (spMAT%type==SPARSE_MATRIX_TYPE_COO) spMAT%IRN(m)=ii
             spMAT%JCN(m)=i0+jdof
             !spMAT%A(m)=hecMAT%D(offset_d+jdof)
             m=m+1
          enddo
          ! Upper
          ls=hecMAT%indexU(i-1)+1
          le=hecMAT%indexU(i)
          do l=ls,le
             j=hecMAT%itemU(l)
             if (j <= hecMAT%N) then
                j0=spMAT%OFFSET+ndof*(j-1)
             else
                j0=spMAT%conv_ext(ndof*(j-hecMAT%N))-ndof
                if (sparse_matrix_is_sym(spMAT) .and. j0 < i0) cycle
             endif
             !offset_u=ndof2*(l-1)+ndof*(idof-1)
             do jdof=1,ndof
                if (spMAT%type==SPARSE_MATRIX_TYPE_COO) spMAT%IRN(m)=ii
                spMAT%JCN(m)=j0+jdof
                !spMAT%A(m)=hecMAT%AU(offset_u+jdof)
                m=m+1
             enddo
          enddo
       enddo
    enddo
    if (spMAT%type == SPARSE_MATRIX_TYPE_CSR) spMAT%IRN(ii+1-spMAT%OFFSET)=m
    if (sparse_matrix_is_sym(spMAT) .and. m-1 < spMAT%NZ) spMAT%NZ=m-1
    if (m-1 /= spMAT%NZ) then
       write(*,*) 'ERROR: sparse_matrix_set_ij on rank ',myrank
       write(*,*) 'm-1 = ',m-1,', NZ=',spMAT%NZ
       stop
    endif
  end subroutine sparse_matrix_hec_set_prof

  subroutine sparse_matrix_hec_set_vals(spMAT, hecMAT)
    type(sparse_matrix), intent(inout) :: spMAT
    type(hecmwST_matrix), intent(in) :: hecMAT
    integer(kind=kint) :: ndof, ndof2
    integer(kind=kint) :: m, i, idof, i0, ii, ls, le, l, j, j0, jdof, jdofs
    integer(kind=kint) :: offset_l, offset_d, offset_u
    ndof=hecMAT%NDOF; ndof2=ndof*ndof
    m=1
    do i=1,hecMAT%N
       do idof=1,ndof
          i0=spMAT%OFFSET+ndof*(i-1)
          ii=i0+idof
          if (spMAT%type == SPARSE_MATRIX_TYPE_CSR .and. spMAT%IRN(ii-spMAT%OFFSET)/=m) &
               stop "ERROR: sparse_matrix_set_a"
          ! Lower
          if (.not. sparse_matrix_is_sym(spMAT)) then
             ls=hecMAT%indexL(i-1)+1
             le=hecMAT%indexL(i)
             do l=ls,le
                j=hecMAT%itemL(l)
                !if (j <= hecMAT%N) then
                j0=spMAT%OFFSET+ndof*(j-1)
                !else
                !   j0=spMAT%conv_ext(ndof*(j-hecMAT%N))-ndof
                !endif
                offset_l=ndof2*(l-1)+ndof*(idof-1)
                do jdof=1,ndof
                   if (spMAT%type==SPARSE_MATRIX_TYPE_COO .and. spMAT%IRN(m)/=ii) &
                        stop "ERROR: sparse_matrix_set_a"
                   if (spMAT%JCN(m)/=j0+jdof) stop "ERROR: sparse_matrix_set_a"
                   spMAT%A(m)=hecMAT%AL(offset_l+jdof)
                   m=m+1
                enddo
             enddo
          endif
          ! Diag
          offset_d=ndof2*(i-1)+ndof*(idof-1)
          if (sparse_matrix_is_sym(spMAT)) then; jdofs=idof; else; jdofs=1; endif
          do jdof=jdofs,ndof
             if (spMAT%type==SPARSE_MATRIX_TYPE_COO .and. spMAT%IRN(m)/=ii) &
                  stop "ERROR: sparse_matrix_set_a"
             if (spMAT%JCN(m)/=i0+jdof) stop "ERROR: sparse_matrix_set_a"
             spMAT%A(m)=hecMAT%D(offset_d+jdof)
             m=m+1
          enddo
          ! Upper
          ls=hecMAT%indexU(i-1)+1
          le=hecMAT%indexU(i)
          do l=ls,le
             j=hecMAT%itemU(l)
             if (j <= hecMAT%N) then
                j0=spMAT%OFFSET+ndof*(j-1)
             else
                j0=spMAT%conv_ext(ndof*(j-hecMAT%N))-ndof
                if (sparse_matrix_is_sym(spMAT) .and. j0 < i0) cycle
             endif
             offset_u=ndof2*(l-1)+ndof*(idof-1)
             do jdof=1,ndof
                if (spMAT%type==SPARSE_MATRIX_TYPE_COO .and. spMAT%IRN(m)/=ii) &
                     stop "ERROR: sparse_matrix_set_a"
                if (spMAT%JCN(m)/=j0+jdof) stop "ERROR: sparse_matrix_set_a"
                spMAT%A(m)=hecMAT%AU(offset_u+jdof)
                m=m+1
             enddo
          enddo
       enddo
    enddo
    if (spMAT%type == SPARSE_MATRIX_TYPE_CSR .and. spMAT%IRN(ii+1-spMAT%OFFSET)/=m) &
         stop "ERROR: sparse_matrix_set_a"
    if (m-1 /= spMAT%NZ) stop "ERROR: sparse_matrix_set_a"
  end subroutine sparse_matrix_hec_set_vals

  subroutine sparse_matrix_hec_set_rhs(spMAT, hecMAT)
    implicit none
    type (sparse_matrix), intent(inout) :: spMAT
    type (hecmwST_matrix), intent(in) :: hecMAT
    integer(kind=kint) :: ierr,i
    allocate(spMAT%rhs(spMAT%N_loc), stat=ierr)
    if (ierr /= 0) then
      write(*,*) " Allocation error, spMAT%rhs"
      call hecmw_abort(hecmw_comm_get_comm())
    endif
    do i=1,spMAT%N_loc
      spMAT%rhs(i)=hecMAT%b(i)
    enddo
  end subroutine sparse_matrix_hec_set_rhs

  subroutine sparse_matrix_hec_get_rhs(spMAT, hecMAT)
    implicit none
    type (sparse_matrix), intent(inout) :: spMAT
    type (hecmwST_matrix), intent(inout) :: hecMAT
    integer(kind=kint) :: i
    do i=1,spMAT%N_loc
      hecMAT%x(i)=spMAT%rhs(i)
    enddo
    deallocate(spMAT%rhs)
  end subroutine sparse_matrix_hec_get_rhs

end module m_sparse_matrix_hec