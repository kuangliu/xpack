packer = dofile('./pack.lua')

packer.pack{
    directory='/mnt/hgfs/D/dataset/cifar10/train/',
    imsize=32,
    packsize = 1000
}

-- packer.pack{
--     directory='../dataset/cifar-class/train/',
--     imsize=32,
--     packsize = 1000
-- }

-- packer.packlist{
--     directory='./images/',
--     list='./images/names.txt',
--     imsize=32,
--     packsize = 1000
-- }
--
-- a = torch.load('./package/pkg_1.t7')
