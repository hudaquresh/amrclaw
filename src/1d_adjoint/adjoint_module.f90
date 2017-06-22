! ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
! ::::::     Module to define and work with adjoint type
! ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

module adjoint_module
    use amr_reload_module

    type adjointData_type

        integer lenmax, lendim, isize, lentot
        real(kind=8), allocatable, dimension(:) :: alloc

        real(kind=8) hxposs(maxlv),possk(maxlv)
        integer icheck(maxlv)

        ! for space management of alloc array
        integer lfree(lfdim,2),lenf

        real(kind=8) rnode(rsize, maxgr)
        integer node(nsize, maxgr), lstart(maxlv),newstl(maxlv), &
                listsp(maxlv)
        integer ibuff, mstart, ndfree, ndfree_bnd, lfine, iorder, mxnest, &
                intratx(maxlv), kratio(maxlv), &
                iregsz(maxlv), iregst(maxlv), &
                iregend(maxlv), numgrids(maxlv), kcheck, &
                nsteps, matlabu, iregridcount(maxlv)
        real(kind=8) time, tol, rvoll(maxlv),evol,rvol, &
                     cflmax, avenumgrids(maxlv)

        ! variable for conservation checking
        real(kind=8) tmass0

    end type adjointData_type

    type(adjointData_type), allocatable :: adjoints(:)
    integer :: totnum_adjoints, nvar, naux, &
               counter, innerprod_index
    real(kind=8) :: trange_start, trange_final
    character(len=365), allocatable :: adj_files(:)
    logical :: adjoint_flagging

contains

    subroutine read_adjoint_data(adjointFolder)

        use amr_reload_module
        implicit none

        ! Function Arguments
        character(len=*), parameter :: adjointfile = 'adjoint.data'
        character(len=*), intent(in) :: adjointFolder
        logical :: fileExists
        integer :: iunit, k
        real(kind=8) :: finalT

        adjoint_flagging = .true.

        inquire(file=adjointfile, exist=fileExists)
        if (fileExists) then

            ! Reload adjoint files
            call amr1_reload(adjointFolder)
            iunit = 16
            call opendatafile(iunit,adjointfile)

            read(iunit,*) totnum_adjoints
            read(iunit,*) innerprod_index
            allocate(adj_files(totnum_adjoints))

            do 20 k = 1, totnum_adjoints
                read(iunit,*) adj_files(totnum_adjoints + 1 - k)
            20  continue
            close(iunit)

            if (size(adj_files) <= 0) then
                print *, 'Error: no adjoint output files found.'
                stop
            endif

            ! Allocate space for the number of needed checkpoint files
            allocate(adjoints(totnum_adjoints))

            do 50 k = 1, totnum_adjoints
                ! Load checkpoint files
                call reload(adj_files(k),k)
            50 continue

        else
            print *, 'Error: adjoint.data file does not exist.'
        endif

    end subroutine read_adjoint_data

    subroutine set_time_window(t1, t2)

        implicit none

        ! Function Arguments
        real(kind=8), intent(in) :: t1, t2

        trange_final = t2
        trange_start = t1

    end subroutine set_time_window

end module adjoint_module
