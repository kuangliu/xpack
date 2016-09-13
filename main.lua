packer = dofile('./pack.lua')

packer.pack{
    directory='/mnt/hgfs/D/dataset/cifar10/train/',
    imsize=32,
    packsize=10000,
    prefix='train'
}

-- packer.packlist{
--     directory='./images/',
--     list='./images/names.txt',
--     imsize=32,
--     packsize=1000,
--     prefix='train'
-- }


dofile('./packloader.lua')

trainloader = PackLoader{ prefix='train' }
x,y = trainloader:sample(100)
print(#x)
print(#y)
