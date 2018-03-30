program climatology_init
#ifdef USE_MPI
  use mpi
#endif
  use tools
  implicit none
  integer :: ierr, unit, global_seed
  real(kind=4), allocatable :: grid(:,:)
  character(len=300) :: outfile
  namelist/settings/ nx,ny,global_seed,outfile
#ifdef USE_MPI
  call MPI_Init(ierr)
#endif
  nx=0
  ny=0
  global_seed=0
  outfile='out.grid'
  open(file='climatology_init.nl',status='old',newunit=unit)
  read(unit,settings)
  close(unit)

  call decompose
  if(rank0) write(0,'(A)') 'Init generator...'
  call init_generator(global_seed)

  if(nj>0) then
     allocate(grid(i1:i2,j1:j2))
  else
     if(rank0) then
        write(0,'(A,I0,": ",A)') &
             'ERROR: Some ranks have no data.  Use no more than ',&
             ny,'ranks.'
     end if
     call abort()
     allocate(grid(1,1))
  endif
  if(rank0) write(0,'(A)') 'Fill field...'
  call fill_field(grid)
  if(rank0) write(0,'(A)') 'Write...'
  call write(outfile,grid)
  if(rank0) write(0,'(A)') 'Exit...'
#ifdef USE_MPI
  call MPI_Finalize(ierr)
#endif
end program climatology_init
  
