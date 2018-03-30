SHELL=/bin/sh
EXES=$(DIR)/forecast $(DIR)/climatology_init $(DIR)/assimilate \
     $(DIR)/post

.PHONY: default theia-impi all

default:
	@echo Run:
	@echo make theia-impi

theia-impi:
	source /apps/lmod/lmod/init/sh ; \
	module purge ; \
	module load intel impi ; \
	module list ; \
	make SM_CC=icc SM_FC=ifort DM_CC=mpiicc DM_FC=mpiifort \
	   SM_CFLAGS="-O3" \
	   DM_CFLAGS="-O3" \
	   DM_FFLAGS="-O3" \
	   OPENMP="-openmp" NO_OPENMP="-diag-disable 3180" \
	   MPI="-DUSE_MPI" NO_MPI="" \
	   all

########################################################################

all: build_serial build_mpi build_openmp build_mpi_openmp

clean:
	rm -f */*.o */*.mod */*~ *~

bare: clean
	rm -f ../exec/*/*

exes: $(EXES)

########################################################################

build_serial: 
	mkdir -p serial && \
	mkdir -p ../exec/serial && \
	cd serial && \
	make -f ../Makefile \
	   SM_CC="$(SM_CC)" DM_CC="$(SM_CC)" DM_FC="$(SM_FC)" \
	  SM_CFLAGS="$(SM_CFLAGS) $(NO_MPI) $(NO_OPENMP)" \
	  DM_CFLAGS="$(DM_CFLAGS) $(NO_MPI) $(NO_OPENMP)" \
	  DM_FFLAGS="$(DM_FFLAGS) $(NO_MPI) $(NO_OPENMP)" \
	  DIR=../../exec/serial exes

build_openmp: 
	mkdir -p openmp \
	mkdir -p ../exec/openmp && \
	cd openmp && \
	make -f ../Makefile \
	   SM_CC="$(SM_CC)" DM_CC="$(SM_CC)" DM_FC="$(SM_FC)" \
	  SM_CFLAGS="$(SM_CFLAGS) $(NO_MPI)    $(OPENMP)" \
	  DM_CFLAGS="$(DM_CFLAGS) $(NO_MPI)    $(OPENMP)" \
	  DM_FFLAGS="$(DM_FFLAGS) $(NO_MPI)    $(OPENMP)" \
	  DIR=../../exec/openmp exes

build_mpi: 
	mkdir -p mpi && \
	mkdir -p ../exec/mpi && \
	cd mpi && \
	make -f ../Makefile \
	   SM_CC="$(SM_CC)" DM_CC="$(DM_CC)" DM_FC="$(DM_FC)" \
	  SM_CFLAGS="$(SM_CFLAGS) $(NO_MPI) $(NO_OPENMP)" \
	  DM_CFLAGS="$(DM_CFLAGS)    $(MPI) $(NO_OPENMP)" \
	  DM_FFLAGS="$(DM_FFLAGS)    $(MPI) $(NO_OPENMP)" \
	  DIR=../../exec/mpi exes

build_mpi_openmp: 
	mkdir -p mpi-openmp \
	mkdir -p ../exec/mpi-openmp && \
	cd mpi-openmp && \
	make -f ../Makefile \
	  SM_CC="$(SM_CC)" DM_CC="$(DM_CC)" DM_FC="$(DM_FC)" \
	  SM_CFLAGS="$(SM_CFLAGS) $(NO_MPI)    $(OPENMP)" \
	  DM_CFLAGS="$(DM_CFLAGS)    $(MPI)    $(OPENMP)" \
	  DM_FFLAGS="$(DM_FFLAGS)    $(MPI)    $(OPENMP)" \
	  DIR=../../exec/mpi-openmp exes

########################################################################

$(DIR)/climatology_init: ../climatology_init.F90 tools.o bobrand.o
	$(DM_FC) $(DM_FFLAGS) -o $@ $^

$(DIR)/forecast: ../forecast.F90 tools.o bobrand.o
	$(DM_FC) $(DM_FFLAGS) -o $@ $^

$(DIR)/assimilate: ../assimilate.F90 tools.o bobrand.o
	$(DM_FC) $(DM_FFLAGS) -o $@ $^

$(DIR)/post: ../post.F90 tools.o bobrand.o
	$(DM_FC) $(DM_FFLAGS) -o $@ $^

bobrand.o: ../bobrand.c
	$(SM_CC) $(SM_CFLAGS) -c -o $@ $^

tools.o: ../tools.F90
	$(DM_FC) $(DM_FFLAGS) -c -o $@ $^
