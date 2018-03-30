program post
#ifdef USE_MPI
  use mpi
#endif
  use tools
  implicit none
  integer :: ierr, unit
  real(kind=4), allocatable :: grid(:,:)
  character(len=300) :: infile
  double precision :: n
  real(kind=4) :: min, max, mean, stdev

  namelist/settings/ nx,ny,infile
#ifdef USE_MPI
  call MPI_Init(ierr)
#endif

  nx=0
  ny=0
  infile='in.grid'
  open(file='post.nl',status='old',newunit=unit)
  read(unit,settings)
  close(unit)

  call decompose
  if(nj<=0) then
     if(rank0) write(0,'(A,I0,A)') &
          'ERROR: Some ranks have no data.  Use no more than ',&
          ny,'ranks.'
     call abort
  endif

  allocate(grid(i1:i2,j1:j2))

  if(rank0) write(0,'(A,A)') trim(infile),': read...'
  call read(infile,grid)

  call global_stats(grid,n,min,max,mean,stdev)

  if(rank0) then
     print *,'points:',idint(n)
     print *,'max:',max
     print *,'min:',min
     print *,'mean:',mean
     print *,'stdev:',stdev
  end if

#ifdef USE_MPI
  call MPI_Barrier(MPI_COMM_WORLD,ierr)
  if(rank0) write(0,'(A)') 'Finalize...'
  call MPI_Finalize(ierr)
#endif
end program post
  
