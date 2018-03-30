program assimilate
#ifdef USE_MPI
  use mpi
#endif
  use tools
  implicit none
  integer :: ierr, unit, members, member, j, i
  real(kind=4), allocatable :: work(:,:), output(:,:)
  character(len=300) :: ensemble_format,guess_in,analysis_out,filename
  namelist/settings/ nx,ny,members,ensemble_format,guess_in,&
       analysis_out

#ifdef USE_MPI
  call MPI_Init(ierr)
#endif

  nx=0
  ny=0
  members=20
  analysis_out='analysis.grid'
  ensemble_format='member_######.grid'
  guess_in='guess.grid'
  open(file='assimilate.nl',status='old',newunit=unit)
  read(unit,settings)
  close(unit)

  call decompose
  if(nj<=0) then
     if(rank0) write(0,'(A,I0,A)') &
          'ERROR: Some ranks have no data.  Use no more than ',&
          ny,'ranks.'
     call abort
  endif

  allocate(work(i1:i2,j1:j2))
  allocate(output(i1:i2,j1:j2))

  if(rank0) write(0,'(A,A)') trim(guess_in),': read...'
  call read(guess_in,output)

  member_loop: do member=1,members
     call format_filename(filename,ensemble_format,member)
     if(rank0) write(0,'(A,A)') trim(filename),': read...'
     call read(filename,work)

     do j=j1,j2
        !$OMP PARALLEL DO PRIVATE(I)
        do i=i1,i2
           output(i,j)=output(i,j)+work(i,j)
        enddo
     enddo
  enddo member_loop

  do j=j1,j2
     !$OMP PARALLEL DO PRIVATE(I)
     do i=i1,i2
        output(i,j)=output(i,j)/sqrt(real(members+1))
     enddo
  enddo

  if(rank0) write(0,'(A,": ",A)') trim(analysis_out),'Write...'
  call write(analysis_out,output)

  if(rank0) write(0,'(A)') 'Exit...'
#ifdef USE_MPI
  call MPI_Finalize(ierr)
#endif
end program assimilate
  
