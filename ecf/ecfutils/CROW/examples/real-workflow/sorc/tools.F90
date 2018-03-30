module tools
  implicit none
  integer :: nx, ny
  integer :: j1, j2, nj
  integer :: i1, i2, ni
  integer, allocatable :: starts(:), ends(:), extents(:)
  integer, allocatable :: state(:,:) ! random number generator state
  logical :: rank0=.true.

contains

  ! ----------------------------------------------------------------

  subroutine decompose
#ifdef USE_MPI
    use mpi
    implicit none
    integer :: i, rank, size, ierr

    call MPI_Comm_rank(MPI_COMM_WORLD,rank,ierr)
    call MPI_Comm_size(MPI_COMM_WORLD,size,ierr)

    rank0 = rank==0

    allocate(starts(size))
    allocate(ends(size))
    allocate(extents(size))

    !$OMP PARALLEL DO PRIVATE(I)
    do i=1,size
       starts(i)=floor(ny/real(size)*(i-1))+1
       ends(i)=floor(ny/real(size)*i)
       extents(i)=ends(i)-starts(i)+1
!       if(rank==0) then
!          print 10,i-1,starts(i),ends(i),extents(i),extents(i)*nx
!       end if
    enddo
    
    j1=starts(rank+1)
    j2=ends(rank+1)
    nj=j2-j1+1

    !$OMP PARALLEL DO PRIVATE(I)
    do i=1,size
       starts(i)=(starts(i)-1)*nx
       ends(i)=(ends(i)-1)*nx
       extents(i)=extents(i)*nx
!       if(rank==0) then
!          print 20,i-1,starts(i),extents(i)
!       end if
    end do

    i1=1
    i2=nx
    ni=nx

10  format('Rank ',I3,': j=',I0,'..',I0,' (count=',I0,' element=',I0,')')
20  format('Rank ',I3,': start=',I0,' extent=',I0)
#else
    i1=1
    i2=nx
    ni=nx
    j1=1
    j2=ny
    nj=ny
#endif

!   print *, i1,i2,ni,nx
!   print *, j1,j2,nj,ny
  end subroutine decompose

  ! ----------------------------------------------------------------

  subroutine abort
#ifdef USE_MPI
    use mpi
#endif
    implicit none
    integer :: ierr
    write(0,*) 'Abort.'
#ifdef USE_MPI
    call MPI_Abort(MPI_COMM_WORLD,1,ierr)
#endif
    stop 1
  end subroutine abort

  ! ----------------------------------------------------------------

  subroutine format_filename(filename,pattern,itime)
    implicit none
    character(len=*), intent(in) :: pattern
    character(len=*), intent(out) :: filename
    character(len=20) :: fmt
    integer :: itime

    integer :: n, ihash, inot, hashlen, i

    n=len_trim(pattern)
    do ihash=1,n
       if(pattern(ihash:ihash) == '#') exit
    enddo
    do inot=ihash+1,n
       if(pattern(inot:inot) /= '#') exit
    enddo

    hashlen=inot-ihash
    if(hashlen<1 .or. ihash==1 .or. inot>n) then
       write(0,20) trim(pattern)
       call abort()
    end if
    write(fmt,10) hashlen
    write(filename,fmt) pattern(1:ihash-1),itime,pattern(inot:n)

    do i=1,len_trim(filename)
       if(filename(i:i) == ' ') filename(i:i)='0'
    enddo

10  format("(A,I",I0,",A)")
20  format(A,": invalid pattern.  Must be prefix###suffix ; ### will be replaced with time.")
  end subroutine format_filename

  ! ----------------------------------------------------------------

  subroutine init_generator(global_seed)
#ifdef USE_MPI
    use mpi
#endif
    implicit none
    integer, intent(in) :: global_seed
    integer :: seeds(i1:i2)
    integer i

    if(nj<0) return ! this rank is inactive

    if(.not. allocated(state)) then
       allocate(state(i1:i2,4))
    endif

    !$OMP PARALLEL DO PRIVATE(I)
    do i=i1,i2
       seeds(i)=i
    enddo
    call bobraninit(state(i1,1),state(i1,2),state(i1,3),state(i1,4), &
         seeds,global_seed,ni)
  end subroutine init_generator

  ! ----------------------------------------------------------------

  subroutine fill_field(f)
    implicit none
    real(kind=4), intent(inout) :: f(i1:i2,j1:j2)
    real(kind=4) :: uniform(i1:i2), mid
    integer :: j,i

    do j=j1,j2
       call bobranval_r4(state(i1,1),state(i1,2),state(i1,3),state(i1,4), &
            uniform(i1), ni)
       !$OMP PARALLEL DO PRIVATE(I,mid)
       do i=i1,i2
          mid=(uniform(i)-0.5)*2.  ! convert to uniform [-1..1)
          f(i,j)=sqrt(-2*log(abs(mid))) ! to gaussian
          if(mid<0) f(i,j)=-f(i,j) ! recover sign
       enddo
    enddo
  end subroutine fill_field

  ! ----------------------------------------------------------------

  subroutine timestep(f,n)
    implicit none
    real(kind=4), intent(inout) :: f(i1:i2,j1:j2)
    integer, intent(in) :: n
    real(kind=4) :: uniform(i1:i2), mid,normal
    integer :: j,i
    integer :: t

    j_loop: do j=j1,j2

       ! Calculate and sum gaussians
       iter_loop: do t=1,n
          call bobranval_r4(state(i1,1),state(i1,2),state(i1,3),state(i1,4), &
               uniform(i1), ni)
          !$OMP PARALLEL DO PRIVATE(I,mid,normal)
          normal_loop: do i=i1,i2
             mid=(uniform(i)-0.5)*2.  ! convert to uniform [-1..1)
             normal=sqrt(-2*log(abs(mid))) ! to gaussian
             if(mid<0) normal=-normal ! recover sign
             f(i,j)=f(i,j)+normal
          enddo normal_loop
       enddo iter_loop

       ! Divide by count to get original stdev
       average_loop: do i=i1,i2
          f(i,j)=f(i,j)/sqrt(real(n+1))
       enddo average_loop

    enddo j_loop
    call sanity_check(f,'timestep')
  end subroutine timestep

  ! ----------------------------------------------------------------

  subroutine sanity_check(grid,why)
    implicit none
    real(kind=4), intent(in) :: grid(i1:i2,j1:j2)
    character(len=*), intent(in) :: why
    real(kind=4) :: stdev, mean, min, max
    double precision :: n

    call global_stats(grid,n,min,max,mean,stdev)
    if( ( stdev<1 .or. stdev>2 .or. &
          max>20 .or. min<-20 .or. &
          mean>1 .or. mean<-1 ) &
        .and. rank0) then
       write(0,'(A, A)') why,': suspicious data:'
       write(0,'(A, I0)') 'points:',idint(n)
       write(0,'(A, G22.14)') 'max:',max
       write(0,'(A, G22.14)') 'min:',min
       write(0,'(A, G22.14)') 'mean:',mean
       write(0,'(A, G22.14)') 'stdev:',stdev
       call abort()
    endif
  end subroutine sanity_check

  ! ----------------------------------------------------------------

  subroutine global_stats(grid,n,minval,maxval,mean,stdev)
#ifdef USE_MPI
    use mpi
#endif
    implicit none
    real(kind=4), intent(in) :: grid(i1:i2,j1:j2)
    real(kind=4), intent(inout) :: stdev, mean, minval, maxval
    double precision, intent(inout) :: n

    integer i, j, ierr

    double precision :: local_sum, local_sumsq, global_sum, global_sumsq
    real(kind=4) :: local_min, local_max, global_max, global_min

    local_sum=0
    local_sumsq=0
    local_min=grid(i1,j1)
    local_max=grid(i1,j1)
    do j=j1,j2
       !$OMP PARALLEL DO private(i) reduction(+:local_sum) &
       !$OMP             reduction(+:local_sumsq) reduction(max:local_max) &
       !$OMP             reduction(min:local_min)
       do i=i1,i2
          local_sum=local_sum+grid(i,j)
          local_sumsq=local_sumsq+grid(i,j)*grid(i,j)
          if(grid(i,j)<local_min) local_min=grid(i,j)
          if(grid(i,j)>local_max) local_max=grid(i,j)
       enddo
    enddo

#ifdef USE_MPI
    call MPI_Allreduce(local_min,global_min,1,MPI_REAL4,MPI_MIN,MPI_COMM_WORLD,ierr)
    call MPI_Allreduce(local_max,global_max,1,MPI_REAL4,MPI_MAX,MPI_COMM_WORLD,ierr)
    call MPI_Allreduce(local_sum,global_sum,1,MPI_DOUBLE_PRECISION,MPI_SUM,MPI_COMM_WORLD,ierr)
    call MPI_Allreduce(local_sumsq,global_sumsq,1,MPI_DOUBLE_PRECISION,MPI_SUM,MPI_COMM_WORLD,ierr)
#else
    global_min=local_min
    global_max=local_max
    global_sum=local_sum
    global_sumsq=local_sumsq
#endif
    
    n=nx
    n=n*ny
    mean=global_sum/n
    stdev=sqrt((global_sumsq-mean*global_sum)/(n-1))
    maxval=global_max
    minval=global_min

  end subroutine global_stats

  ! ----------------------------------------------------------------

  subroutine write(file,local)
#ifdef USE_MPI
    use mpi
#endif
    implicit none
    real(kind=4), intent(in) :: local(i1:i2,j1:j2)
    real(kind=4), allocatable :: global(:,:)
    integer :: ierr, unit
    character(len=*) ,intent(in) :: file

    call sanity_check(local,'write')

#ifdef USE_MPI    
    if(rank0) then
       allocate(global(nx,ny))
    else
       allocate(global(1,1))
    end if

    call MPI_Gatherv(local(i1,j1),ni*nj,MPI_REAL4, &
                     global,extents,starts,MPI_REAL4, &
                     0,MPI_COMM_WORLD,ierr)
#endif

    if(rank0) then
       OPEN(newunit=unit, FILE=trim(file), STATUS="REPLACE", ACCESS="STREAM")
       WRITE(unit) nx
       WRITE(unit) ny
#ifdef USE_MPI    
       write(unit) global
    deallocate(global)
#else
       write(unit) local
#endif
       close(unit)
    end if
#ifdef USE_MPI
    call MPI_Barrier(MPI_COMM_WORLD,ierr)
#endif

  end subroutine write

  ! ----------------------------------------------------------------

  subroutine read(file,local)
#ifdef USE_MPI
    use mpi
#endif
    implicit none
    real(kind=4), intent(out) :: local(i1:i2,j1:j2)
    real(kind=4), allocatable :: global(:,:)
    integer :: ierr, unit, nx_file, ny_file, buf(2), i, j
    character(len=*), intent(in) :: file

    !omp parallel do private(i,j)
    do j=j1,j2
       do i=i1,i2
          local(i,j)=0
       enddo
    enddo
    if(rank0) then
       OPEN(newunit=unit, FILE=trim(file), STATUS="OLD", ACCESS="STREAM")
       read(unit) nx_file
       read(unit) ny_file

       if(nx_file /= nx .or. ny_file /= ny) then
          !write(0,10) nx_file,ny_file,nx,ny
          close(unit)
          call abort()
       end if

       buf = (/ nx_file, ny_file /)
    endif
#ifdef USE_MPI
    call MPI_Bcast(buf,2,MPI_INTEGER,0,MPI_COMM_WORLD,ierr)
    nx_file=buf(1)
    ny_file=buf(2)

    if(rank0) then
       allocate(global(nx,ny))
    else
       allocate(global(1,1))
    end if

    if(rank0) then
       read(unit) global
       close(unit)
    endif
    call MPI_Scatterv(global,extents,starts,MPI_REAL4, &
                      local,ni*nj,MPI_REAL4, &
                      0,MPI_COMM_WORLD,ierr)
    deallocate(global)
#else
    read(unit) local
#endif

    call sanity_check(local,'read')
10  format('File size does not match namelist. File: ',I0,'x',I0,' /= namelist ',I0,'x',I0)
  end subroutine read
end module tools
