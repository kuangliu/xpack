packer = dofile('./pack.lua')

-- packer.pack('/mnt/hgfs/D/dataset/cifar10/test/airplane/', 32)
packer.pack{
    directory='../dataset/cifar-class/test/airplane/',
    imsize=32,
    packsize = 900
}

-- a = torch.load('./package/airplane_2.t7')
