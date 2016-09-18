# xpack
Yet another data loading module for Torch.  

We adopt the [MXNet](https://mxnet.readthedocs.io/en/latest/system/note_data_loading.html)
data loading philosophy which packs raw images into big packages that can still be loaded into memory one by one.
And instead of loading raw images, loading bigger continuous packages should be more efficient.

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


## `packlist`
Pack images based on the list file (each line is the image path and targets separated by lines).

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
Unlike `pack`, `packsplit` first split dataset into train/val/test set, and pack them individually.

```lua
packer.packsplit{
    directory='/mnt/hgfs/D/dataset/cifar10/',
    imsize=32,
    packsize=10000,
    partition={train=0.8, test=0.2}
}
```
`packsplit` splits dataset based on the `partition` table.  
Internally, it first splits the list file, and uses `packlist` to do the job.

## `packloader`
`packloader` loads saved packages, and provides `sample` and `get` interfaces for training.

```lua
dofile('./packloader.lua')

trainloader = PackLoader{ prefix='train' }
x,y = trainloader:sample(100)
print(#x)
print(#y)
```
