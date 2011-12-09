!======================================================================!
!                                                                      !
! Software Name : FrontISTR Ver. 3.2                                   !
!                                                                      !
!      Module Name : m_set_arrays_directsolver_contact                 !
!                                                                      !
!            Written by Z. Sun(ASTOM)                                  !
!                                                                      !
!                                                                      !
!      Contact address :  IIS,The University of Tokyo, CISS            !
!                                                                      !
!      "Structural Analysis for Large Scale Assembly"                  !
!                                                                      !
!======================================================================!
!======================================================================!
!
!> \brief This module provides functions to set arrays for direcr sparse solver 
!> \in the case of using standard Lagrange multiplier algorithm for contact analysis.  
!>
!>  \author     Z. Sun(ASTOM)
!>  \date       2010/11   
!>  \version    0.00
!!
!======================================================================!

module m_set_arrays_directsolver_contact               

   use m_fstr                                                  
   use fstr_matrix_con_contact 
   
   implicit none

   integer (kind=kint), allocatable :: pointers(:)        !< ia     
   integer (kind=kint), allocatable :: indices(:)         !< ja    
   real (kind=kreal)   , allocatable :: values(:)          !< a                    

   logical :: symmetricMatrixStruc   

  contains  


!> \brief This subroutine sets index arrays for direct sparse solver from those stored 
!> \in the matrix structures defined in MODULE fstr_matrix_con_contact     
    subroutine set_pointersANDindices_directSolver(hecMAT,fstrMAT)
    
      type(hecmwST_matrix)                     :: hecMAT    !< type hecmwST_matrix
      type (fstrST_matrix_contact_lagrange)    :: fstrMAT   !< type fstrST_matrix_contact_lagrange
    
      integer (kind=kint)     :: np                         !< total number of nodes
      integer (kind=kint)     :: ndof                       !< degree of freedom
      integer (kind=kint)     :: num_lagrange               !< total number of Lagrange multipliers
      integer (kind=kint)     :: nn                         !< size of pointers
      integer (kind=kint)     :: numNon0                    !< total number of non-zero items(elements) of stiffness matrix
      integer (kind=kint)     :: ierr                       !< error indicateor
      integer (kind=kint)     :: i, j, k, l, countNon0  
                   
      np = hecMAT%NP ; ndof = hecMAT%NDOF ; num_lagrange = fstrMAT%num_lagrange
      nn = np*ndof + num_lagrange + 1
     
      if( symmetricMatrixStruc )then                                 
        numNon0 = hecMAT%NPU*ndof**2+hecMAT%NP*ndof*(ndof+1)/2 &
                + (fstrMAT%numU_lagrange)*ndof+fstrMAT%num_lagrange
      else 
        numNon0 = (hecMAT%NPL+hecMAT%NPU+hecMAT%NP)*ndof**2 &
                + (fstrMAT%numL_lagrange+fstrMAT%numU_lagrange)*ndof 
      endif
              
      if(allocated(pointers))deallocate(pointers)
      allocate(pointers(nn), stat=ierr) 
      if( ierr /= 0 ) stop " Allocation error, mkl%pointers "
      pointers = 0 
      
      if(allocated(indices))deallocate(indices) 
      allocate(indices(numNon0), stat=ierr) 
      if( ierr /= 0 ) stop " Allocation error, mkl%indices " 
      indices = 0
      
      if(allocated(values))deallocate(values)   
      allocate(values(numNon0), stat=ierr) 
      if( ierr /= 0 ) stop " Allocation error, mkl%values " 
      values = 0.0D0
   
      pointers(1) = 1
      countNon0 = 1    
      
      do i = 1, np 
        do j = 1, ndof
          if( .not. symmetricMatrixStruc )then                                
            do l = hecMAT%indexL(i-1)+1, hecMAT%indexL(i)      
              do k = 1, ndof
                indices(countNon0) = (hecMAT%itemL(l)-1)*ndof + k
                countNon0 = countNon0 + 1
              enddo
            enddo
            do k = 1, j-1                                                
              indices(countNon0) = (i-1)*ndof + k
              countNon0 = countNon0 + 1
            enddo                                                        
          endif                                                           
          do k = j, ndof                                                 
            indices(countNon0) = (i-1)*ndof + k
            countNon0 = countNon0 + 1
          enddo
          do l = hecMAT%indexU(i-1)+1, hecMAT%indexU(i)
            do k = 1, ndof
              indices(countNon0) = (hecMAT%itemU(l)-1)*ndof + k
              countNon0 = countNon0 + 1
            enddo
          enddo
          if( num_lagrange > 0 )then                                         
            do l = fstrMAT%indexU_lagrange(i-1)+1, fstrMAT%indexU_lagrange(i)    
              indices(countNon0) = np*ndof + fstrMAT%itemU_lagrange(l) 
              countNon0 = countNon0 + 1    
            enddo
          endif
          pointers((i-1)*ndof+j+1) = countNon0
        enddo         
      enddo  
     
      if( num_lagrange > 0 )then                                              
        do i = 1, num_lagrange
          if( symmetricMatrixStruc )then                                     
            indices(countNon0) = np*ndof + i
            countNon0 = countNon0 + 1   
          else                                                               
            do l = fstrMAT%indexL_lagrange(i-1)+1, fstrMAT%indexL_lagrange(i)
              do k = 1, ndof
                indices(countNon0) = (fstrMAT%itemL_lagrange(l)-1)*ndof + k 
                countNon0 = countNon0 + 1
              enddo  
            enddo 
          endif                                                 
          pointers(np*ndof+i+1) = countNon0 
        enddo
      endif                                                     
  
    end subroutine set_pointersANDindices_directsolver    

  
!> \brief This subroutine sets the array for direct sparse solver that contains
!> \the non-zero items(elements)of stiffness matrix from those stored 
!> \in the matrix structures defined in MODULE fstr_matrix_con_contact
    subroutine set_values_directsolver(hecMAT,fstrMAT)  
    
      type(hecmwST_matrix)                    :: hecMAT    !< type hecmwST_matrix
      type (fstrST_matrix_contact_lagrange)   :: fstrMAT   !< type fstrST_matrix_contact_lagrange 
                                      
      integer (kind=kint)     :: np                        !< total number of nodes
      integer (kind=kint)     :: ndof                      !< degree of freedom
      integer (kind=kint)     :: num_lagrange              !< total number of Lagrange multipliers
      integer (kind=kint)     :: numNon0                   !< total number of non-zero items(elements) of stiffness matrix
      integer (kind=kint)     :: ierr                      !< error indicator
      integer (kind=kint)     :: i, j, k, l  
      integer (kind=kint)     :: countNon0, locINal, locINd, locINau, locINal_lag, locINau_lag    
               
      np = hecMAT%NP ; ndof = hecMAT%NDOF ; num_lagrange = fstrMAT%num_lagrange
  
      if( symmetricMatrixStruc )then                                 
        numNon0 = hecMAT%NPU*ndof**2+hecMAT%NP*ndof*(ndof+1)/2 &
                + (fstrMAT%numU_lagrange)*ndof+fstrMAT%num_lagrange
      else                                                            
        numNon0 = (hecMAT%NPL+hecMAT%NPU+hecMAT%NP)*ndof**2 &
                + (fstrMAT%numL_lagrange+fstrMAT%numU_lagrange)*ndof 
      endif                                                                
              
        
      if(allocated(values))deallocate(values)    
      allocate(values(numNon0), stat=ierr) 
      if( ierr /= 0 ) stop " Allocation error, mkl%values " 
      values = 0.0D0

      countNon0 = 1                            
      do i = 1, np 
        do j = 1, ndof
          if( .not. symmetricMatrixStruc )then                               
            do l = hecMAT%indexL(i-1)+1, hecMAT%indexL(i)      
              do k = 1, ndof
                locINal = ((l-1)*ndof+j-1)*ndof + k                     
                values(countNon0) = hecMAT%AL(locINal)
                countNon0 = countNon0 + 1
              enddo
            enddo
            do k = 1, j-1
              locINd = ((i-1)*ndof+j-1)*ndof + k                       
              values(countNon0) = hecMAT%D(locINd)
              countNon0 = countNon0 + 1
            enddo                                                             
          endif                                                              
          do k = j, ndof
            locINd = ((i-1)*ndof+j-1)*ndof + k                       
            values(countNon0) = hecMAT%D(locINd)
            countNon0 = countNon0 + 1
          enddo
          do l = hecMAT%indexU(i-1)+1, hecMAT%indexU(i)
            do k = 1, ndof
              locINau = ((l-1)*ndof+j-1)*ndof + k                     
              values(countNon0) = hecMAT%AU(locINau)     
              countNon0 = countNon0 + 1
            enddo
          enddo
          if( num_lagrange > 0 )then                                
            do l = fstrMAT%indexU_lagrange(i-1)+1, fstrMAT%indexU_lagrange(i)   
              locINau_lag = (l-1)*ndof + j
              values(countNon0) = fstrMAT%AU_lagrange(locINau_lag) 
              countNon0 = countNon0 + 1    
            enddo
          endif                                                     
        enddo                    
      enddo                     
  
      if( .not.symmetricMatrixStruc .and. num_lagrange > 0 )then      
        do i = 1, num_lagrange
          do l = fstrMAT%indexL_lagrange(i-1)+1, fstrMAT%indexL_lagrange(i)
            do k = 1, ndof
              locINal_lag = (l-1)*ndof + k 
              values(countNon0) = fstrMAT%AL_lagrange(locINal_lag)  
              countNon0 = countNon0 + 1
            enddo  
          enddo 
        enddo
      endif 
      
    end subroutine set_values_directsolver    

    !> \brief this function judges whether sitiffness matrix is symmetric or not     
    logical function fstr_is_matrixStruct_symmetric(fstrSOLID)        
     
       type(fstr_solid )     :: fstrSOLID
       fstr_is_matrixStruct_symmetric = .true.
       if( any(fstrSOLID%contacts(:)%fcoeff /= 0.0d0) )  & 
       fstr_is_matrixStruct_symmetric = .false.   
     
     end function          


end module m_set_arrays_directsolver_contact