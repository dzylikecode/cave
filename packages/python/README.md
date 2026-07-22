# python

## python bridge

对于这个[hello_world_need_python_home](example/hello_world_need_python_home.cpp)需要指定 python 的 home 才能运行

eg. windows powershell

```bash
$env:PYTHONHOME="$env:USERPROFILE\AppData\Local\.xmake\packages\p\python\3.8.10\5740ece21ecb4ee3a72178ec965adbef"
xmake run need_home
```

> 要这样才能运行，要不然就是复制exe到 `$env:USERPROFILE\AppData\Local\.xmake\packages\p\python\3.8.10\5740ece21ecb4ee3a72178ec965adbef` 下面，或者 `$env:USERPROFILE\AppData\Roaming\uv\python\cpython-3.8-windows-x86_64-none`


然而这无疑是麻烦的，不如获取当前环境的python home，在程序中指定默认 home，再考虑虚拟环境来测试

采用 uv 来创建虚拟环境来测试

```bash
uv venv --python 3.8 --seed
```

可以通过python来获取python的home目录

```bash
python -c "import sys; print(sys.base_prefix)"
```

获取虚拟环境

```bash
python -c "import sys; print(sys.prefix)"
```
