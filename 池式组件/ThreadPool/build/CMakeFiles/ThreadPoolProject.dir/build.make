# CMAKE generated file: DO NOT EDIT!
# Generated by "Unix Makefiles" Generator, CMake Version 3.22

# Delete rule output on recipe failure.
.DELETE_ON_ERROR:

#=============================================================================
# Special targets provided by cmake.

# Disable implicit rules so canonical targets will work.
.SUFFIXES:

# Disable VCS-based implicit rules.
% : %,v

# Disable VCS-based implicit rules.
% : RCS/%

# Disable VCS-based implicit rules.
% : RCS/%,v

# Disable VCS-based implicit rules.
% : SCCS/s.%

# Disable VCS-based implicit rules.
% : s.%

.SUFFIXES: .hpux_make_needs_suffix_list

# Command-line flag to silence nested $(MAKE).
$(VERBOSE)MAKESILENT = -s

#Suppress display of executed commands.
$(VERBOSE).SILENT:

# A target that is always out of date.
cmake_force:
.PHONY : cmake_force

#=============================================================================
# Set environment variables for the build.

# The shell in which to execute make rules.
SHELL = /bin/sh

# The CMake executable.
CMAKE_COMMAND = /usr/bin/cmake

# The command to remove a file.
RM = /usr/bin/cmake -E rm -f

# Escaping for special characters.
EQUALS = =

# The top-level source directory on which CMake was run.
CMAKE_SOURCE_DIR = /home/shawn/projects/Pool/ThreadPool

# The top-level build directory on which CMake was run.
CMAKE_BINARY_DIR = /home/shawn/projects/Pool/ThreadPool/build

# Include any dependencies generated for this target.
include CMakeFiles/ThreadPoolProject.dir/depend.make
# Include any dependencies generated by the compiler for this target.
include CMakeFiles/ThreadPoolProject.dir/compiler_depend.make

# Include the progress variables for this target.
include CMakeFiles/ThreadPoolProject.dir/progress.make

# Include the compile flags for this target's objects.
include CMakeFiles/ThreadPoolProject.dir/flags.make

CMakeFiles/ThreadPoolProject.dir/main.cpp.o: CMakeFiles/ThreadPoolProject.dir/flags.make
CMakeFiles/ThreadPoolProject.dir/main.cpp.o: ../main.cpp
CMakeFiles/ThreadPoolProject.dir/main.cpp.o: CMakeFiles/ThreadPoolProject.dir/compiler_depend.ts
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green --progress-dir=/home/shawn/projects/Pool/ThreadPool/build/CMakeFiles --progress-num=$(CMAKE_PROGRESS_1) "Building CXX object CMakeFiles/ThreadPoolProject.dir/main.cpp.o"
	/usr/bin/c++ $(CXX_DEFINES) $(CXX_INCLUDES) $(CXX_FLAGS) -MD -MT CMakeFiles/ThreadPoolProject.dir/main.cpp.o -MF CMakeFiles/ThreadPoolProject.dir/main.cpp.o.d -o CMakeFiles/ThreadPoolProject.dir/main.cpp.o -c /home/shawn/projects/Pool/ThreadPool/main.cpp

CMakeFiles/ThreadPoolProject.dir/main.cpp.i: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Preprocessing CXX source to CMakeFiles/ThreadPoolProject.dir/main.cpp.i"
	/usr/bin/c++ $(CXX_DEFINES) $(CXX_INCLUDES) $(CXX_FLAGS) -E /home/shawn/projects/Pool/ThreadPool/main.cpp > CMakeFiles/ThreadPoolProject.dir/main.cpp.i

CMakeFiles/ThreadPoolProject.dir/main.cpp.s: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Compiling CXX source to assembly CMakeFiles/ThreadPoolProject.dir/main.cpp.s"
	/usr/bin/c++ $(CXX_DEFINES) $(CXX_INCLUDES) $(CXX_FLAGS) -S /home/shawn/projects/Pool/ThreadPool/main.cpp -o CMakeFiles/ThreadPoolProject.dir/main.cpp.s

# Object files for target ThreadPoolProject
ThreadPoolProject_OBJECTS = \
"CMakeFiles/ThreadPoolProject.dir/main.cpp.o"

# External object files for target ThreadPoolProject
ThreadPoolProject_EXTERNAL_OBJECTS =

ThreadPoolProject: CMakeFiles/ThreadPoolProject.dir/main.cpp.o
ThreadPoolProject: CMakeFiles/ThreadPoolProject.dir/build.make
ThreadPoolProject: CMakeFiles/ThreadPoolProject.dir/link.txt
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green --bold --progress-dir=/home/shawn/projects/Pool/ThreadPool/build/CMakeFiles --progress-num=$(CMAKE_PROGRESS_2) "Linking CXX executable ThreadPoolProject"
	$(CMAKE_COMMAND) -E cmake_link_script CMakeFiles/ThreadPoolProject.dir/link.txt --verbose=$(VERBOSE)

# Rule to build all files generated by this target.
CMakeFiles/ThreadPoolProject.dir/build: ThreadPoolProject
.PHONY : CMakeFiles/ThreadPoolProject.dir/build

CMakeFiles/ThreadPoolProject.dir/clean:
	$(CMAKE_COMMAND) -P CMakeFiles/ThreadPoolProject.dir/cmake_clean.cmake
.PHONY : CMakeFiles/ThreadPoolProject.dir/clean

CMakeFiles/ThreadPoolProject.dir/depend:
	cd /home/shawn/projects/Pool/ThreadPool/build && $(CMAKE_COMMAND) -E cmake_depends "Unix Makefiles" /home/shawn/projects/Pool/ThreadPool /home/shawn/projects/Pool/ThreadPool /home/shawn/projects/Pool/ThreadPool/build /home/shawn/projects/Pool/ThreadPool/build /home/shawn/projects/Pool/ThreadPool/build/CMakeFiles/ThreadPoolProject.dir/DependInfo.cmake --color=$(COLOR)
.PHONY : CMakeFiles/ThreadPoolProject.dir/depend

