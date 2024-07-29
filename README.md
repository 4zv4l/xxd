# xxd

basic xxd clone in Zig

## usage

```
usage: xxd [option] [file]

Options:
    -r     reverse operation (hex dump -> bytes)
```

dump file

```
$ ./xxd test
00000000: 4865 6c6c 6f2c 2057 6f72 6c64 2021 2046  Hello, World ! F
00000010: 6f6f 2042 6172 0a                        oo Bar.
```

load from dump (hex to bytes)

```
$ ./xxd -r test_hex
Hello, World ! Foo Bar
```

it can also read from stdin if piped

```
$ ./xxd test | ./xxd -r | ./xxd
00000000: 4865 6c6c 6f2c 2057 6f72 6c64 2021 2046  Hello, World ! F
00000010: 6f6f 2042 6172 0a                        oo Bar.
```

## how to compile

with the zig compiler

```
$ zig build-exe -D ReleaseSmall xxd.zig
```
