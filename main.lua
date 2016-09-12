-- packer = dofile('./pack.lua')
--
-- packer.pack{
--     directory='/mnt/hgfs/D/dataset/cifar10/test/',
--     imsize=32,
--     packsize=3000,
--     prefix='test'
-- }

-- packer.packlist{
--     directory='./images/',
--     list='./images/names.txt',
--     imsize=32,
--     packsize=1000,
--     prefix='train'
-- }


dofile('./packloader.lua')

packloader = PackLoader{ directory='./package/', prefix='test', packsize=10000 }
