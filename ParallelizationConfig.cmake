# file with configuration that is common to both OpenMP and MPI.
# It is included from both OpenMPConfig and MPIConfig.

if(NOT DEFINED PARALLELIZATION_CONFIG_INCLUDED)
	set(PARALLELIZATION_CONFIG_INCLUDED TRUE)
	
	if(OPENMP OR MPI)
		set(PARALLEL TRUE)
	else()
		set(PARALLEL FALSE)
	endif()
	
	# --------------------------------------------------------------------
	# Mixing Compiler Paralleization Workaround
	# --------------------------------------------------------------------
	
	# Since cmake-buildscripts v1.1, MPI and OpenMP compiler flags are passed around via targets (mpi_cxx, openmp_fortran, etc.).
	# All is fine and dandy when this setup is used to build single-language programs.
	# However, we get in trouble when mixed language programs (like sff or pmemd) use OpenMP and MPI because flags for different compilers will get jammed together.
	# The fix is to use CMake's $<COMPILE_LANGUAGE> generator expression so that the flags will be deleted if they are passed to the wrong compiler.
	# However, this doesn't work on CMake < 3.3, or with Visual Studio, so we have to warn the user appropriately
	
	set(MCPAR_WORKAROUND_ENABLED FALSE)
	
	if(MIXING_COMPILERS AND PARALLEL)
		if("${CMAKE_VERSION}" VERSION_GREATER 3.3 OR "${CMAKE_VERSION}" VERSION_EQUAL 3.3)
			if("${CMAKE_GENERATOR}" MATCHES "Visual Studio")
				message(WARNING "You are using parallelization, and are mixing compilers from different vendors.  This is not supported with Visual Studio due to a CMake technical limitation. \
You may get compiler errors caused by the wrong flags getting passed to compilers on mixed-language programs.  To build in this configuration, please use NMake or JOM.")
			else()
				set(MCPAR_WORKAROUND_ENABLED TRUE)
			endif()
		else()
			message(WARNING  "You are using parallelization, and are mixing compilers from different vendors.  To make this configuration work properly, CMake >= 3.3 is required. \
Please upgrade CMake, or you may get compiler errors in this configuration.")
		endif()
	endif()

endif()