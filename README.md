# xpack
Yet another data loading module for Torch.  

We adopt the [MXNet](https://mxnet.readthedocs.io/en/latest/system/note_data_loading.html)
data loading policy that packs raw images into big packages, which still can be loaded into memory. And instead of loading raw images, loading bigger continuous packages should be more efficient.

## `pack`
Pack images organized in sub-folders, the sub-folder name is the class name.

```lua
packer = dofile('./pack.lua')

packer.pack{
    directory='/mnt/hgfs/D/dataset/cifar10/train/',
    imsize=32,
    packsize=10000,
    prefix='train'
}
```
- `directory`: directory containing all the class folders
- `imsize`: image target size
- `packsize`: # of images per package
- `prefix`: train/test  

The packages are saved as `./package/prefix/part_i.t7`.

## `packlist`
Pack images based on the list file (each line is the image path and targets separated by spaces).

```lua
packer.packlist{
    directory='./images/',
    list='./images/names.txt',
    imsize=32,
    packsize=10000,
    prefix='train'
}
```

## `packsplit`
Unlike `pack`, `packsplit` splits the dataset first by the `partition` table, and pack them individually.  
Internally, it splits the list file and uses `packlist` to pack.

```lua
packer.packsplit{
    directory='/mnt/hgfs/D/dataset/cifar10/',
    imsize=32,
    packsize=10000,
    partition={train=0.8, test=0.2}
}
```

## `packloader`
`packloader` loads saved packages, and provides `sample` and `get` interfaces for training.

```lua
dofile('./packloader.lua')

trainloader = PackLoader{
    directory='./package/',
    prefix='train'
}
x, y = trainloader:sample(100)
print(#x)
print(#y)
```

## `packloader` vs. `dataloader`
Multi-thread dynamic dataloader like `listdataloader`, `classdataloader` is great, and works really well.

Let's take an example, VGGNet takes nearly `1` second to train a batch with `128` samples. And loading `128` samples from a normal HDD disk needs nearly `2` seconds.
- training time: `tt = 1`
- data time: `dt = 2`


So how many threads do we need to avoid the data loading overhead? `dt/tt=2/1=2`.  
In my experiment, with only `2` threads, the overhead time decrease to `< 1ms`. And in the whole data loading + training process, the only bottleneck is the training time.

For `packloader`, with a single thread, loading a `128` sized batch from a package takes `10ms`, and with `2` threads, the overhead time `< 3ms`.

So when we prefer `packloader`?  
Let's say the data loading time `dt=2` seconds, as we use a simple CNN that only needs `tt=100ms` per batch training. If we can't afford `dt/tt=20` threads, say at most `8` threads, then the data loading is the bottleneck of the whole process. That's when `packloader` is preferred.  
So when data loading overhead is the main issue of the training process, consider use `packloader`.
> It's seems it's really rare that `packloader` could be used...not to mention the long and frustrating data packing time... Damn!
