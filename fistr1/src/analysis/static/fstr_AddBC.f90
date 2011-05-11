!======================================================================!
!                                                                      !
! Software Name : FrontISTR Ver. 3.0                                   !
!                                                                      !
!      Module Name : Static Analysis                                   !
!                                                                      !
!            Written by K. Sato(Advancesoft), X. YUAN(AdavanceSoft)    !
!                                                                      !
!                                                                      !
!      Contact address :  IIS,The University of Tokyo, CISS            !
!                                                                      !
!      "Structural Analysis for Large Scale Assembly"                  !
!                                                                      !
!======================================================================!
!======================================================================!
!
!> \brief  This module provides a function to deal with prescribed displacement.
!!
!>  \author     K. Sato(Advancesoft), X. YUAN(AdavanceSoft)
!>  \date       2009/08/31
!>  \version    0.00
!!
!======================================================================!
module m_fstr_AddBC

   implicit none

   contains
   
!>  Add Essential Boundary Conditions
!----------------------------------------------------------------------*
      subroutine fstr_AddBC(cstep,substep,hecMESH,hecMAT,fstrSOLID,iter)
!----------------------------------------------------------------------*
      use m_fstr
      integer, intent(in)       :: cstep     !< current step
      integer, intent(in)       :: substep   !< current substep
      type (hecmwST_local_mesh) :: hecMESH   !< hecmw mesh
      type (hecmwST_matrix)     :: hecMAT    !< hecmw matrix
      type (fstr_solid        ) :: fstrSOLID !< fstr_solid
      integer(kind=kint)        :: iter      !< NR iterations

      integer(kind=kint) :: ig0, ig, ityp, idofS, idofE, idof, iS0, iE0, ik, in
      real(kind=kreal) :: RHS,factor 
      integer(kind=kint) :: idof1, idof2, ndof, i, grpid
!
      factor = fstrSOLID%FACTOR(2)-fstrSOLID%FACTOR(1)
	  
      if( cstep<=fstrSOLID%nstep_tot .and. fstrSOLID%step_ctrl(cstep)%solution==stepVisco ) then
         factor = 0.d0
         if( substep==1 ) factor=1.d0
      endif
      if( iter>1 ) factor=0.d0
!   ----- Prescibed displacement Boundary Conditions
      do ig0 = 1, fstrSOLID%BOUNDARY_ngrp_tot
        grpid = fstrSOLID%BOUNDARY_ngrp_GRPID(ig0)
        if( .not. fstr_isBoundaryActive( fstrSOLID, grpid, cstep ) ) cycle
        ig   = fstrSOLID%BOUNDARY_ngrp_ID(ig0)
        RHS  = fstrSOLID%BOUNDARY_ngrp_val(ig0)
!
        RHS= RHS*factor
!
        ityp = fstrSOLID%BOUNDARY_ngrp_type(ig0)
        idofS = ityp/10
        idofE = ityp - idofS*10
!
        iS0 = hecMESH%node_group%grp_index(ig-1) + 1
        iE0 = hecMESH%node_group%grp_index(ig  )
!
        do ik = iS0, iE0
          in = hecMESH%node_group%grp_item(ik)
!
          do idof = idofS, idofE
            call hecmw_mat_ass_bc(hecMAT, in, idof, RHS)
          enddo
        enddo
      enddo
!
!   ------ Equation boundary conditions
      do ig0=1,fstrSOLID%n_fix_mpc
          if( fstrSOLID%mpc_const(ig0) == 0.d0 ) cycle
      ! we need to confirm if it is active in curr step here
          RHS = fstrSOLID%mpc_const(ig0)*factor
          hecMESH%mpc%mpc_const(ig0) = RHS
      enddo
!C
!C Message
!C
      if( hecMESH%my_rank==0) then
         write(IMSG,*) '####fstr_AddBC finished'
      end if

      end subroutine fstr_AddBC

end module m_fstr_AddBC