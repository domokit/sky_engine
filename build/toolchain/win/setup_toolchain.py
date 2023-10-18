# Copyright (c) 2013 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#
# Copies the given "win tool" (which the toolchain uses to wrap compiler
# invocations) and the environment blocks for the 32-bit and 64-bit builds on
# Windows to the build directory.
#
# The arguments are the visual studio install location and the location of the
# win tool. The script assumes that the root build directory is the current dir
# and the files will be written to the current directory.

import errno
import os
import re
import subprocess
import sys


def _ExtractImportantEnvironment(output_of_set):
  """Extracts environment variables required for the toolchain to run from
  a textual dump output by the cmd.exe 'set' command."""
  envvars_to_save = (
      'goma_.*', # TODO(scottmg): This is ugly, but needed for goma.
      'include',
      'lib',
      'libpath',
      'path',
      'pathext',
      'systemroot',
      'temp',
      'tmp',
      )
  env = {}
  for line in output_of_set.splitlines():
    for envvar in envvars_to_save:
      if re.match(envvar + '=', line.decode().lower()):
        var, setting = line.decode().split('=', 1)
        if envvar == 'path':
          # Our own rules (for running gyp-win-tool) and other actions in
          # Chromium rely on python being in the path. Add the path to this
          # python here so that if it's not in the path when ninja is run
          # later, python will still be found.
          setting = os.path.dirname(sys.executable) + os.pathsep + setting
        env[var.upper()] = setting
        break
  for required in ('SYSTEMROOT', 'TEMP', 'TMP'):
    if required not in env:
      raise Exception('Environment variable "%s" '
                      'required to be set to valid path' % required)
  return env


def _SetupScript(target_cpu, sdk_dir):
  """Returns a command (with arguments) to be used to set up the
  environment."""
  # Check if we are running in the SDK command line environment and use
  # the setup script from the SDK if so.
  accepted_cpus = ('x86', 'x64', 'arm64')
  assert target_cpu in accepted_cpus, '%s not in accepted cpus %s' % (target_cpu, accepted_cpus)
  if bool(int(os.environ.get('DEPOT_TOOLS_WIN_TOOLCHAIN', 1))) and sdk_dir:
    return [os.path.normpath(os.path.join(sdk_dir, 'Bin/SetEnv.Cmd')),
            '/' + target_cpu]
  else:
    vcvars_arch = {
        'x86': 'amd64_x86',
        'x64': 'amd64',
        'arm64': 'amd64_arm64',
    }
    # We only support x64-hosted tools.
    # TODO(scottmg|dpranke): Non-depot_tools toolchain: need to get Visual
    # Studio install location from registry.
    return [os.path.normpath(os.path.join(os.environ['GYP_MSVS_OVERRIDE_PATH'],
                                          'VC/Auxiliary/Build/vcvarsall.bat')),
            vcvars_arch[target_cpu]]


def _FormatAsEnvironmentBlock(envvar_dict):
  """Format as an 'environment block' directly suitable for CreateProcess.
  Briefly this is a list of key=value\0, terminated by an additional \0. See
  CreateProcess documentation for more details."""
  block = ''
  nul = '\0'
  for key, value in envvar_dict.items():
    block += key + '=' + value + nul
  block += nul
  return block


def _CopyTool(source_path):
  """Copies the given tool to the current directory, including a warning not
  to edit it."""
  with open(source_path) as source_file:
    tool_source = source_file.readlines()

  # Add header and write it out to the current directory (which should be the
  # root build dir).
  with open("gyp-win-tool", 'w') as tool_file:
    tool_file.write(''.join([tool_source[0],
                             '# Generated by setup_toolchain.py do not edit.\n']
                            + tool_source[1:]))


def main():
  if len(sys.argv) != 5:
    print('Usage setup_toolchain.py '
          '<visual studio path> <win sdk path> '
          '<runtime dirs> <target_cpu>')
    sys.exit(2)
  win_sdk_path = sys.argv[2]
  runtime_dirs = sys.argv[3]
  target_cpu = sys.argv[4]

  cpus = ('x86', 'x64', 'arm64')
  assert target_cpu in cpus
  vc_bin_dir = ''

  # TODO(scottmg|goma): Do we need an equivalent of
  # ninja_use_custom_environment_files?

  for cpu in cpus:
    # Extract environment variables for subprocesses.
    args = _SetupScript(cpu, win_sdk_path)
    args.extend(('&&', 'set'))
    popen = subprocess.Popen(
        args, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    variables, _ = popen.communicate()
    env = _ExtractImportantEnvironment(variables)
    env['PATH'] = runtime_dirs + ';' + env['PATH']

    if cpu == target_cpu:
      for path in env['PATH'].split(os.pathsep):
        if os.path.exists(os.path.join(path, 'cl.exe')):
          vc_bin_dir = os.path.realpath(path)
          break

    # The Windows SDK include directories must be first. They both have a sal.h,
    # and the SDK one is newer and the SDK uses some newer features from it not
    # present in the Visual Studio one.

    if win_sdk_path:
      additional_includes = ('{sdk_dir}\\Include\\shared;' +
                             '{sdk_dir}\\Include\\um;' +
                             '{sdk_dir}\\Include\\winrt;').format(
                                  sdk_dir=win_sdk_path)
      env['INCLUDE'] = additional_includes + env['INCLUDE']
    env_block = _FormatAsEnvironmentBlock(env)
    with open('environment.' + cpu, 'wb') as f:
      f.write(env_block.encode())

  assert vc_bin_dir
  print('vc_bin_dir = "%s"' % vc_bin_dir)


if __name__ == '__main__':
  main()
