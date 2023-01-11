#!/bin/csh
# Copyright (c) 2020-2022, Xilinx, Inc.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
#
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
#
# * Neither the name of FINN nor the names of its
#   contributors may be used to endorse or promote products derived from
#   this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

set env_flag=0
if ( ! $?FINN_XILINX_PATH ) then
  echo "Please set the FINN_XILINX_PATH environment variable to the path to your Xilinx tools installation directory (e.g. /opt/Xilinx)."
  echo "FINN functionality depending on Vivado, Vitis or HLS will not be available."
  env_flag=1
endif

if ( ! $?FINN_XILINX_VERSION ) then
  echo "Please set the FINN_XILINX_VERSION to the version of the Xilinx tools to use (e.g. 2020.1)"
  echo "FINN functionality depending on Vivado, Vitis or HLS will not be available."
  env_flag=1
endif

if ( ! $?PLATFORM_REPO_PATHS ) then
  echo "Please set PLATFORM_REPO_PATHS pointing to Vitis platform files (DSAs)."
  echo "This is required to be able to use Alveo PCIe cards."
  env_flag=1
endif

if ( ! $?SPACK_PATH ) then
  echo "Please set SPACK_PATH pointing to spack setup script."
  echo "This is required to be able to set workspace environment."
  env_flag=1
endif

if ( $env_flag == 1 ) then
  echo "Correctly set Env Variables as described above"
  return $env_flag
endif

# Absolute path to this script, e.g. /home/user/bin/foo.sh
set SCRIPTPATH=`pwd`
if ( ! -f $SCRIPTPATH/no-docker-env.csh ) then
  echo "Rerun from finn root"
  exit
endif

set REQUIREMENTS="$SCRIPTPATH/requirements_full.txt"
set REQUIREMENTS_TEMPLATE="$SCRIPTPATH/requirements_template.txt"

# Set paths for local python requirements
cat $REQUIREMENTS_TEMPLATE | sed "s|SCRIPTPATH|$SCRIPTPATH|gi" > $REQUIREMENTS

# the settings below will be taken from environment variables if available,
# otherwise the defaults below will be used
if ( ! $?FINN_SKIP_DEP_REPOS ) then
  setenv FINN_SKIP_DEP_REPOS 0
else if ( $FINN_SKIP_DEP_REPOS == "") then
  setenv FINN_SKIP_DEP_REPOS 0
endif

if ( ! $?FINN_ROOT ) then
  setenv FINN_ROOT $SCRIPTPATH
else if ( $FINN_ROOT == "") then
  setenv FINN_ROOT $SCRIPTPATH
endif

if ( ! $?FINN_BUILD_DIR ) then
  setenv FINN_BUILD_DIR "$FINN_ROOT/../tmp"
else if ( $FINN_BUILD_DIR == "") then
  setenv FINN_BUILD_DIR "$FINN_ROOT/../tmp"
endif

if ( ! $?VENV_NAME ) then
  setenv VENV_NAME "finn_venv"
else if ( $VENV_NAME == "") then
  setenv VENV_NAME "finn_venv"
endif

if ( ! $?VENV_PATH ) then
  setenv VENV_PATH `realpath "$SCRIPTPATH/.."`
else if ( $VENV_PATH == "") then
  setenv VENV_PATH `realpath "$SCRIPTPATH/.."`
endif

set VENV_PATH_FULL "$SCRIPTPATH/$VENV_NAME"

# Ensure git-based deps are checked out at correct commit
if [ "$FINN_SKIP_DEP_REPOS" = "0" ]; then
  ./fetch-repos.sh
fi

# Activate Spack environment
source $SPACK_PATH/setup-env.csh
spack compiler find --scope site
spack env create -d .
spack env activate .
spack install -y

# Create/Activate Python VENV
if ( ! -f "$VENV_PATH_FULL/bin/activate" ) then
  python -m venv $VENV_PATH_FULL
endif
source "$VENV_PATH_FULL/bin/activate.csh"

# Check if requirements have already been installed, install if not
pip install -r $REQUIREMENTS

# ensure build dir exists locally
mkdir -p $FINN_BUILD_DIR

# Ensure git-based deps are checked out at correct commit
if ( $FINN_SKIP_DEP_REPOS == 0 ) then
  ./fetch-repos.sh
endif

if ( $?FINN_XILINX_PATH ) then
  set VITIS_PATH="$FINN_XILINX_PATH/Vitis/$FINN_XILINX_VERSION/"
  if ( -f "$VITIS_PATH/settings64.csh" ) then
    source "$VITIS_PATH/settings64.csh"
    echo "Found Vitis at $VITIS_PATH"
  else
    echo "Unable to find $VITIS_PATH/settings64.csh"
    echo "Functionality dependent on Vitis HLS will not be available."
    echo "Please note that FINN needs at least version 2020.2 for Vitis HLS support."
    echo "If you need Vitis HLS, ensure FINN_XILINX_PATH is set correctly."
  endif
endif