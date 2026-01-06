'''
#!/usr/bin/env python3
import os
from SCons.Variables import Variables, PathVariable
from SCons.Script import DefaultEnvironment, SConscript, Glob, Default

# ---- user-visible defaults (change only if needed) ----
DEFAULT_PIPER_INCLUDE = "/home/frederik/uni/Master/KP/windows-piper/piper1-gpl/libpiper/include"
DEFAULT_PIPER_LIB     = "/home/frederik/uni/Master/KP/windows-piper/piper1-gpl/libpiper/build-win"
DEFAULT_ONNX_LIB      = "/home/frederik/uni/Master/KP/windows-piper/piper1-gpl/libpiper/lib/onnxruntime-win-x64-1.22.0/lib"

# ---- options ----
opts = Variables([], ARGUMENTS)
opts.Add(PathVariable('piper_include_path', 'Path to piper Includes', DEFAULT_PIPER_INCLUDE))
opts.Add(PathVariable('piper_lib_path',     'Path to piper lib',      DEFAULT_PIPER_LIB))
opts.Add(PathVariable('onnx_lib_path',      'Path to onnx lib',       DEFAULT_ONNX_LIB))

# load godot-cpp SConstruct to get godot-cpp env setup
env = SConscript("godot-cpp/SConstruct")
opts.Update(env)

piper_include_path = env['piper_include_path']
piper_lib_path     = env['piper_lib_path']
onnx_lib_path      = env['onnx_lib_path']

# common settings
env.Append(CPPPATH=['.', piper_include_path])
env.Append(CXXFLAGS=["-std=c++17"])

# default library names (generic)
env.Append(LIBPATH=[piper_lib_path])
# add generic names; will be overridden/extended for Windows below
env.Append(LIBS=['piper', 'onnxruntime'])

# linux rpath behaviour (keep your previous behaviour)
if env["platform"] == "linux":
    env.Append(LINKFLAGS=[
        f'-Wl,-rpath,{piper_lib_path}',
        '-Wl,-rpath,$ORIGIN'
    ])

# --- windows-specific adjustments (MinGW cross / native) ---
if env["platform"] == "windows":
    # ensure produced dll has no "lib" prefix
    env['SHLIBPREFIX'] = ''
    env['SHLIBSUFFIX'] = '.dll'

    # prefer absolute import/static lib filenames (so -l lookup is not needed)
    libs_to_add = []

    # piper candidates (common outcomes from your build)
    piper_candidates = [
        os.path.join(piper_lib_path, "libpiper.dll.a"),  # import lib for DLL
        os.path.join(piper_lib_path, "libpiper.a"),      # static lib
        os.path.join(piper_lib_path, "piper.lib"),       # MSVC import lib (if any)
        os.path.join(piper_lib_path, "libpiper.dll"),    # direct DLL (ld may accept; prefer import lib)
    ]
    for c in piper_candidates:
        if os.path.exists(c):
            libs_to_add.append(c)

    # onnxruntime candidates (adjust names if your distribution differs)
    onnx_candidates = [
        os.path.join(onnx_lib_path, "libonnxruntime.dll.a"),
        os.path.join(onnx_lib_path, "libonnxruntime.a"),
        os.path.join(onnx_lib_path, "onnxruntime.lib"),
        os.path.join(onnx_lib_path, "onnxruntime.dll"),
    ]
    for c in onnx_candidates:
        if os.path.exists(c):
            libs_to_add.append(c)

    # if we located absolute libs, use them; otherwise fall back to -L -l behavior
    if libs_to_add:
        # remove generic names to avoid duplicate -lpiper -lonnxruntime
        # and append absolute file paths (SCons will pass them verbatim)
        # First, filter out any generic 'piper'/'onnxruntime' from current LIBS
        env['LIBS'] = [l for l in env.get('LIBS', []) if l not in ('piper', 'onnxruntime')]
        env.Append(LIBS = libs_to_add)
    else:
        # fallback: rely on LIBPATH and generic names (user must ensure files exist)
        env.Append(LIBPATH=[piper_lib_path, onnx_lib_path])
        env.Append(LIBS=['piper', 'onnxruntime'])

    # optional: statically link libstdc++/libgcc to reduce runtime DLLs to ship
    env.Append(LINKFLAGS=['-static-libstdc++', '-static-libgcc'])

# sources & build target (same as your Linux logic)
env.Append(CPPPATH=["src/"])
sources = Glob("src/*.cpp")

if env["platform"] == "macos":
    library = env.SharedLibrary(
        "godot_piper/bin/libpiper_godot.{}.{}.framework/libpiper.{}.{}".format(
            env["platform"], env["target"], env["platform"], env["target"]
        ),
        source=sources,
    )
elif env["platform"] == "ios":
    if env["ios_simulator"]:
        library = env.StaticLibrary(
            "godot_piper/bin/libpiper_godot.{}.{}.simulator.a".format(env["platform"], env["target"]),
            source=sources,
        )
    else:
        library = env.StaticLibrary(
            "godot_piper/bin/libpiper_godot.{}.{}.a".format(env["platform"], env["target"]),
            source=sources,
        )
else:
    library = env.SharedLibrary(
        "godot_piper/bin/libpiper_godot{}{}".format(env["suffix"], env["SHLIBSUFFIX"]),
        source=sources,
    )

Default(library)
'''

#!/usr/bin/env python
import os
import sys

opts = Variables([], ARGUMENTS)
opts.Add(PathVariable('piper_include_path', 'Path to piper Includes', 
                      '/home/frederik/uni/Master/KP/libpiper/install/include'))
opts.Add(PathVariable('piper_lib_path', 'Path to piper lib', 
                      '/home/frederik/uni/Master/KP/libpiper/install/lib'))
opts.Add(PathVariable('onnx_lib_path', 'Path to onnx lib', 
                      '/home/frederik/uni/Master/KP/libpiper/install/lib'))

env = SConscript("godot-cpp/SConstruct")

opts.Update(env)

# For reference:
# - CCFLAGS are compilation flags shared between C and C++
# - CFLAGS are for C-specific compilation flags
# - CXXFLAGS are for C++-specific compilation flags
# - CPPFLAGS are for pre-processor flags
# - CPPDEFINES are for pre-processor defines
# - LINKFLAGS are for linking flags

piper_include_path = env['piper_include_path']
piper_lib_path = env['piper_lib_path']
onnx_lib_path = env['onnx_lib_path']


env.Append(CPPPATH=['.', piper_include_path])
env.Append(LIBPATH=[piper_lib_path])
env.Append(LIBS=['piper', 'onnxruntime'])
env.Append(CXXFLAGS=["-std=c++17"])

if env["platform"] == "linux":
    env.Append(LINKFLAGS=[
        f'-Wl,-rpath,{piper_lib_path}',
#        f'-Wl,-rpath,{onnx_lib_path}',
        '-Wl,-rpath,$ORIGIN'
    ])

#env.Append(CPPPATH=[
#    '.',
#    piper_include_path
#])
#
#env.Append(LINKFLAGS=[
#    f'-Wl,-rpath,{piper_lib_path}',
#    f'-Wl,-rpath,{onnx_lib_path}'
#])
#
#env.Append(LINKFLAGS=['-Wl,-rpath,$ORIGIN'])
#
#env.Append(LIBPATH=[piper_lib_path, onnx_lib_path])
#env.Append(LIBS=['piper', 'onnxruntime'])

# tweak this if you want to use different folders, or more folders, to store your source code in.
env.Append(CPPPATH=["src/"])
sources = Glob("src/*.cpp")

if env["platform"] == "macos":
    library = env.SharedLibrary(
        "mimic-mansion/bin/libpiper_godot.{}.{}.framework/libpiper.{}.{}".format(
            env["platform"], env["target"], env["platform"], env["target"]
        ),
        source=sources,
    )
elif env["platform"] == "ios":
    if env["ios_simulator"]:
        library = env.StaticLibrary(
            "mimic-mansion/bin/libpiper_godot.{}.{}.simulator.a".format(env["platform"], env["target"]),
            source=sources,
        )
    else:
        library = env.StaticLibrary(
            "mimic-mansion/bin/libpiper_godot.{}.{}.a".format(env["platform"], env["target"]),
            source=sources,
        )
else:
    library = env.SharedLibrary(
        "mimic-mansion/bin/libpiper_godot{}{}".format(env["suffix"], env["SHLIBSUFFIX"]),
        source=sources,
    )

Default(library)