c
c -----------------------------------------------------------
c
      subroutine flagger(nvar,naux,lcheck,start_time)

      use amr_module
      use adjoint_module, only: calculate_tol, eptr, errors
      implicit double precision (a-h,o-z)

      integer omp_get_thread_num, omp_get_max_threads
      integer mythread/0/, maxthreads/1/
      integer listgrids(numgrids(lcheck)), locuse

c ::::::::::::::::::::: FLAGGER :::::::::::::::::::::::::
c
c flagger = set up for and call two routines that flag using
c    (a) spatial gradients, or other user-specified criteria
c    (b) richardson error estimates
c
c the two approaches share an array with boundary ghost values 
c
c ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

c      call prepgrids(listgrids,numgrids(lcheck),lcheck)
         mbuff = max(nghost,ibuff+1)  
c before parallel loop give grids the extra storage they need for error estimation

         if (flag_richardson) then
             allocate(errors(numcells(lcheck)))
             allocate(eptr(numgrids(lcheck)))
             errors = 0
             eptr(1) = 0
         endif

         do  jg = 1, numgrids(lcheck)
c            mptr = listgrids(jg)
            levSt  = listStart(lcheck)
            mptr   = listOfgrids(levSt+jg-1)
            nx     = node(ndihi,mptr) - node(ndilo,mptr) + 1
            mitot  = nx + 2*nghost
            if (flag_richardson) then
               locbig = igetsp(mitot*nvar)
               node(tempptr,mptr) = locbig

               if (jg .ne. numgrids(lcheck)) then
                   eptr(jg+1) = eptr(jg)+nx
               endif
            else 
               locbig = 0
            endif
            mibuff = nx + 2*mbuff       ! NOTE THIS NEW DIMENSIONING TO ALLOW ROOM FOR BUFFERING IN PLACE
            locamrflags = igetsp(mibuff)
            node(storeflags,mptr) = locamrflags
          end do

!$OMP PARALLEL DO PRIVATE(jg,mptr,nx,mitot,locnew,locaux),
!$OMP&            PRIVATE(time,dx,xleft,xlow,locbig),
!$OMP&            PRIVATE(locold,mbuff,mibuff,locamrflags,i),
!$OMP&            PRIVATE(locuse),
!$OMP&            SHARED(numgrids,listgrids,lcheck,nghost,nvar,naux),
!$OMP&            SHARED(levSt,listStart,listOfGrids),
!$OMP&            SHARED(tolsp,alloc,node,rnode,hxposs,ibuff),
!$OMP&            SHARED(start_time,possk,flag_gradient,flag_richardson)
!$OMP&            DEFAULT(none),
!$OMP&            SCHEDULE(DYNAMIC,1)
       do  jg = 1, numgrids(lcheck)
c          mptr = listgrids(jg)
          levSt  = listStart(lcheck)
          mptr   = listOfGrids(levSt+jg-1)
          nx     = node(ndihi,mptr) - node(ndilo,mptr) + 1
          mitot  = nx + 2*nghost
          locnew = node(store1,mptr)
          locaux = node(storeaux,mptr)
          time   = rnode(timemult,mptr)
          dx     = hxposs(lcheck)
          xleft  = rnode(cornxlo,mptr)
          xlow   = xleft - nghost*dx
c
          locbig =  node(tempptr,mptr)
c         # straight copy into scratch array so don't mess up latest soln.

c         ## at later times want to use newest soln for spatial error flagging
c         ## at initial time want to use initial conditions (so retain symmetry for example)
         if (start_time+possk(lcheck) .ne. time) then !exact equality test-relying on ieee arith repeatability
c            do in other order in case user messes up locbig in flag2refine, already have
c            them in locnew
             call bound(time,nvar,nghost,alloc(locnew),mitot,mptr,
     1                  alloc(locaux),naux)
             locuse = locnew ! flag based on newest vals
             if (flag_richardson) then
               do 10 i = 1, mitot*nvar
 10             alloc(locbig+i-1) = alloc(locnew+i-1)
             endif

         else   ! boundary values already in locold
             locold = node(store2,mptr)
             locuse = locold ! flag based on old vals at initial time
             ! put back this way to agree with nosetests
             if (flag_richardson) then
               do 11 i = 1, mitot*nvar
 11              alloc(locbig+i-1) = alloc(locold+i-1)
             endif
         endif

!        # need at least as big as nghost to fit ghost cells. if ibuff is bigger make
!        # the flagged array bigger so can buffer in place
         mbuff = max(nghost,ibuff+1)  
         mibuff = nx + 2*mbuff       ! NOTE THIS NEW DIMENSIONING TO ALLOW ROOM FOR BUFFERING IN PLACE

!              ##  locamrflags used for flag storage. flag2refine flags directly into it.
!              ## richardson flags added to it. Then colate finished the job
                locamrflags = node(storeflags,mptr)
                do 20 i = 1, mibuff  ! initialize
 20                alloc(locamrflags+i-1) = goodpt

         if (flag_gradient) then

c     # call user-supplied routine to flag any points where 
c     # refinement is desired based on user's criterion.  
c     # Default version compares spatial gradient to tolsp.

c no longer getting locbig, using "real" solution array in locnew
            call flag2refine1(nx,nghost,mbuff,nvar,naux,
     &                        xleft,dx,time,lcheck,
     &                        tolsp,alloc(locuse),
     &                        alloc(locaux),alloc(locamrflags),
     &                        goodpt,badpt)
             endif     
c     
         if (flag_richardson) then
              call errest(nvar,naux,lcheck,mptr,nx,jg)
         endif

       end do
! $OMP END PARALLEL DO

       if (flag_richardson) then
           call calculate_tol(lcheck)
           deallocate(errors)
           deallocate(eptr)
       endif

       return
       end
