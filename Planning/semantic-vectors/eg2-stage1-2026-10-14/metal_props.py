import ctypes, sys
bin_dir = sys.argv[1]
base = ctypes.CDLL(bin_dir + "/libggml-base.dylib")
ggml = ctypes.CDLL(bin_dir + "/libggml.dylib")
CB = ctypes.CFUNCTYPE(None, ctypes.c_int, ctypes.c_char_p, ctypes.c_void_p)
def emit(level, text, user):
    sys.stdout.write(text.decode("utf-8", "replace"))
cb = CB(emit)
base.ggml_log_set(cb, None)
ggml.ggml_backend_load_all()
ggml.ggml_backend_dev_count.restype = ctypes.c_size_t
print("devices:", ggml.ggml_backend_dev_count())
