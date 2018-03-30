program forecast
#ifdef USE_MPI
  use mpi
#endif
  use tools
  implicit none
  integer :: ierr, unit, global_seed, dt_rand, dt_write
  integer :: start_time, end_time, t
  real(kind=4), allocatable :: grid(:,:)
  character(len=300) :: infile,outfile_format, filename
  namelist/settings/ nx,ny,infile,outfile_format, &
       dt_rand,dt_write,start_time,end_time,global_seed

#ifdef USE_MPI
  call MPI_Init(ierr)
#endif

  global_seed=0
  nx=0
  ny=0
  infile='in.grid'
  outfile_format='output_######.grid'
  dt_rand=10000
  dt_write=10
  start_time=0
  end_time=10*dt_write
  open(file='forecast.nl',status='old',newunit=unit)
  read(unit,settings)
  close(unit)

  call decompose
  if(nj<=0) then
     if(rank0) write(0,'(A,I0,": ",A)') &
          'ERROR: Some ranks have no data.  Use no more than ',&
          ny,'ranks.'
     call abort
  endif

  allocate(grid(i1:i2,j1:j2))

  if(rank0) write(0,'(A,A)') trim(infile),': read...'
  call read(infile,grid)

  time_loop: do t=start_time,end_time
     if(rank0) write(0,'(A)') 'Init generator...'
     call init_generator(global_seed+t)
     
     if(rank0) write(0,'(A)') 'Step time...'
     call timestep(grid,dt_rand)

     if(mod(t,dt_write)/=0) cycle

     call format_filename(filename,outfile_format,t-start_time)
     if(rank0) write(0,'(A,A)') trim(filename),': write...'
     call write(filename,grid)
  enddo time_loop

  if(rank0) write(0,'(A)') 'Exit...'
#ifdef USE_MPI
  call MPI_Finalize(ierr)
#endif
end program forecast
  
