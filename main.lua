-- packer = dofile('./pack.lua')
--
-- packer.pack{
--     directory='/mnt/hgfs/D/dataset/cifar10/train/',
--     imsize=32,
--     packsize=10000,
--     prefix='train'
-- }

-- packer.packlist{
--     directory='./images/',
--     list='./images/names.txt',
--     imsize=32,
--     packsize=1000,
--     prefix='train'
-- }


dofile('./packloader.lua')

packloader = PackLoader{ prefix='train' }


x,y = packloader:sample(1)
print(#x, #y)

x,y = packloader:sample(1)
print(#x, #y)

x,y = packloader:sample(3)
print(#x, #y)

-- for i = 1,9900 do
--     print(i)
--     x,y = packloader:get(i,i+100)
-- end
