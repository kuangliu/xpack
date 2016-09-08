packer = dofile('./pack.lua')

packer.pack{
    directory='/mnt/hgfs/D/dataset/cifar10/train/',
    imsize=32,
    packsize = 1000,
    prefix='train'
}

-- packer.packlist{
--     directory='./images/',
--     list='./images/names.txt',
--     imsize=32,
--     packsize=1000,
--     prefix='train'
-- }
