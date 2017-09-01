#This file contains the logic for deciding which tools (subdirectories in AmberTools) should get built

# Must be included after PythonConfig.cmake and GUIConfig.cmake

#First we list all of the tools, in the correct order. 
#The order IS important, as targets used by one tool have to be added first, 
#and CMake executes these sequentially.


# There are many, many reasons that you would want a tool not to build, and in some cases more than one can occur at the same time
# For that reason, and because order matters, we use a blacklist model for deciding what tools to build.
# We start with all of them enabled, and pare down this list for various reasons in the logic below.
set(AMBER_TOOLS 
#3rd party programs: see 3rdPartyTools.cmake
#	utility routines and libraries:
gbnsr6
lib
cifparse

#	old Amber programs
addles
sander
nmr_aux
nmode

#	antechamber:
antechamber
sqm

#   miscellaneous:
reduce
sebomd
emil
ndiff-2.00

#	cpptraj:
cpptraj

#   nab:
pbsa
sff
rism
nab
nss
etc

#   mdgx:
mdgx

#   xtalutil:
xtalutil

#   saxs and saxs_md:
saxs

#	mm_pbsa
mm_pbsa

#	paramfit
paramfit


#	FEW
FEW

#	amberlite
amberlite

#	cphstats
cphstats

#	quick
quick

#	nfe-umbrella-slice
nfe-umbrella-slice

#   leap
leap

#   python programs
parmed
mmpbsa_py
pymsmt
pysander
pytraj
pymdgx
pdb4amber

#  sort of a 2nd party program -- not written by us, but not a dependency either.
mtkpp)

if(NOT AMBER_RELEASE)
	# these tools are in the git version of amber, but not in the released source
	list(APPEND AMBER_TOOLS 
		chamber
		ptraj
		gleap)
endif()

# save an unaltered copy for disable_all_tools_except()
set(ALL_TOOLS ${AMBER_TOOLS})

set(REMOVED_TOOLS "")
set(REMOVED_TOOL_REASONS "")

#Macro which disables a tool 
macro(disable_tool TOOL REASON)
	
	list(FIND AMBER_TOOLS ${TOOL} STILL_IN_TOOLS)
	list(FIND REMOVED_TOOLS ${TOOL} ALREADY_REMOVED)
	
	
	if(ALREADY_REMOVED EQUAL -1) #If we've already removed the tool, don't do anything
		
		# if the tool is present in neither list, then it means it's a tool that isn't included in the release build and was disabled
		if(NOT STILL_IN_TOOLS EQUAL -1)
			
			list(REMOVE_ITEM AMBER_TOOLS ${TOOL})
			
			list(APPEND REMOVED_TOOLS ${TOOL})
			list(APPEND REMOVED_TOOL_REASONS ${REASON})
		endif()
	endif()
endmacro(disable_tool)

#Macro which disables a list of tools for the same reason
macro(disable_tools REASON) # TOOLS...
	foreach(TOOL ${ARGN})
		disable_tool(${TOOL} ${REASON})
	endforeach()
endmacro(disable_tools)

#Disable all tools except the ones provided for REASON
macro(disable_all_tools_except REASON) # TOOLS...
	foreach(TOOL ${ALL_TOOLS})
		list_contains(KEEP_THIS_TOOL ${TOOL} ${ARGN})
		if(NOT KEEP_THIS_TOOL)
			disable_tool(${TOOL} ${REASON})
		endif()
	endforeach()
endmacro(disable_all_tools_except)

# set the dependencies of a tool
# if one of its dependencies is disabled, then TOOL will also be disabled.
# NOTE: circular dependencies are OK (for example, SANDER and PBSA depend on each other)
macro(tool_depends TOOL) #ARGN: other tools that TOOL depends on
	if(DEFINED TOOL_DEPENDENCIES_${TOOL})
		list(APPEND TOOL_DEPENDENCIES_${TOOL} ${ARGN})
	else()
		set(TOOL_DEPENDENCIES_${TOOL} ${ARGN})
	endif()

endmacro(tool_depends)


# --------------------------------------------------------------------
# tool dependencies
# --------------------------------------------------------------------

tool_depends(pbsa sander lib)
tool_depends(sander sqm pbsa sebomd emil lib)
tool_depends(sqm sff lib)
tool_depends(sebomd sander)

tool_depends(sff pbsa)
tool_depends(nab sff pbsa cifparse)

tool_depends(rism nab lib)

# python programs
tool_depends(pytraj cpptraj)
tool_depends(pysander sander)
tool_depends(pymdgx mdgx)

# extra dependencies if FFT is enabled
if(USE_FFT)
	tool_depends(sff rism)
	tool_depends(sander rism)
endif()
# --------------------------------------------------------------------
# Now, the logic for deciding whether to use them
# --------------------------------------------------------------------

# FFT programs
if(USE_FFT)
	if(${CMAKE_C_COMPILER_ID} STREQUAL PGI)

		# RISM and PBSA FFT solver require ISO_C_BINDING support.
		if(${CMAKE_C_COMPILER_VERSION} VERSION_LESS 9.0.4)
			message(FATAL_ERROR "RISM and PBSA FFT solver require PGI compiler version 9.0-4 or higher. Please disable USE_FFT.")
		endif()
	elseif(${CMAKE_C_COMPILER_ID} STREQUAL Cray) 
		message(FATAL_ERROR "RISM and PBSA FFT solver currently not built with cray compilers.  Please disable USE_FFT.")
	endif()
else()
	disable_tool(rism "Rism requires FFTW")
endif()

#Python programs (controlled by BUILD_PYTHON option in PythonConfig.cmake)
if(NOT BUILD_PYTHON)
	disable_tools("Python programs are disabled" pysander pytraj pysmt mmpbsa_py parmed pymdgx)
endif()

if(STATIC)
	disable_tools("Python programs cannot link to static libraries" pysander pytraj)
endif()

if(MPI AND mpi4py_DISABLED)
	disable_tool(mmpbsa_py "mmpbsa_py requires mpi4py when MPI is enabled")
endif()


# Perl programs
if(NOT BUILD_PERL)
	disable_tools("Perl programs are disabled" FEW mm_pbsa)
endif()

if(perlmol_DISABLED)
	disable_tool(FEW "FEW requires perlmol")
endif()

#deprecated programs
option(BUILD_DEPRECATED "Build outdated and deprecated tools, such as ptraj" FALSE)
if(NOT BUILD_DEPRECATED)
	disable_tool(ptraj "Deprecated tools are disabled")
endif()

# in-development programs
option(BUILD_INDEV "Build Amber programs which are still being developed.  These probably contain bugs, and may not be finished.")
if(NOT BUILD_INDEV)
	disable_tools("In-development programs are disabled." gleap quick pymdgx)
endif()

if(readline_DISABLED)
	disable_tool(gleap "gleap requires the readline library.")
endif()

if(NOT HAVE_GLEAP_DEPENDENCIES)
	disable_tool(gleap "You are missing the required GUI libraries for gleap, gtk2 and gtkglext")
endif()

if(NOT BUILD_SANDER_API)
	disable_tool(pysander "The Sander API is disabled")
endif()

if(CROSSCOMPILE)
	disable_tools("Python programs with native libraries can't be cross-compiled (see Amber bug #337)" pysander pytraj pymdgx parmed)
endif()

# host tools
if(USE_HOST_TOOLS)
	disable_tool(byacc "Using host tools version")
endif()

# PGI won't compile MTK++; see bug 219.
if(${CMAKE_CXX_COMPILER_ID} STREQUAL PGI)
	disable_tool(mtkpp "Not compatible with the PGI C++ compiler.")
endif()

if(MINGW)
	disable_tool(pytraj "pytraj is not currently supported with MinGW. It must be built with MSVC.")
endif() 

disable_all_tools_except("Testing reasons" lib emil cpptraj sff rism pbsa sqm sander nab cifparse sebomd)

# --------------------------------------------------------------------
# Disable certain sets of programs due to the build type
# --------------------------------------------------------------------
if(CRAY)
	# In cray parallel modes, almost all tools are disabled.
	if(MPI)
		disable_all_tools_except("Not supported on Cray in MPI mode" etc sff cpptraj cifparse mdgx nab rism parmed mmpbsa_py)
	elseif(OPENMP)
		disable_all_tools_except("Not supported on Cray in OpenMP mode" sff cifparse nab rism cpptraj pytraj saxs paramfit)

	else()
		disable_tools("Not supported on Cray in serial mode"
			pbsa
			gbnsr6
			sander
			nmr_aux
			nss
			etc
			mmpbsa
			amberlite
			quick)
	endif()
endif()

# --------------------------------------------------------------------
# Disable tools whose dependencies have been disabled
# --------------------------------------------------------------------

# we have to go through this a couple times.  Lets say A depends on B, and B depends on C.
# Early on, A checks if B is there, and it is, so A stays enabled.  Later, B checks if C is there, and it isn't, so
# it disables itself. However, now A is enabled when it shouldn't
# There are probably more sophisticated ways to solve this but they'd be difficult to implement in CMake

# hopefully 3 iterations is enough
foreach(ITERATION RANGE 0 2)
	foreach(TOOL ${AMBER_TOOLS})
		
		foreach(DEPENDENCY ${TOOL_DEPENDENCIES_${TOOL}})
			list_contains(DEPEND_ENABLED ${DEPENDENCY} ${AMBER_TOOLS})
			if(NOT DEPEND_ENABLED)
				disable_tool(${TOOL} "Its dependency ${DEPENDENCY} is disabled.")
			endif()
		endforeach()
	endforeach()
endforeach()

#------------------------------------------------------------------------------
#  User Config
#------------------------------------------------------------------------------
set(DISABLE_TOOLS "" CACHE STRING "Tools to not build.  Accepts a semicolon-seperated list of directories in AmberTools/src.")
disable_tools("Disabled by user" ${DISABLE_TOOLS})
