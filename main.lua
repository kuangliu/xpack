packer = dofile('./pack.lua')

packer.pack('/mnt/hgfs/D/dataset/cifar10/test/airplane/', 32)


a = torch.load('./airplane_11.t7')
#a
itorch.image(a[80])
