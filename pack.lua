----------------------------------------------------------------------------
-- This module packs individual image files into a continuous package, for
-- fast data loading.
-- The packages are named as "classname_idx.t7".
----------------------------------------------------------------------------

require 'xlua'
require 'image'
local argcheck = require 'argcheck'

local M = {}
local pathcat = paths.concat

torch.setdefaulttensortype('torch.FloatTensor')

--------------------------------------------------------
-- packs the images under the given directory
--
function M.pack(opt)
    local check = argcheck{
        {name='directory', type='string', help='directory containing all the images'},
        {name='imsize', type='number', help='image target size'},
        {name='packsize', type='number', help='# of images per package', default=10000}
    }
    local directory, imsize, packsize = check(opt)

    paths.mkdir('package')
    -- # of files in the directory
    local N = tonumber(sys.fexecute('ls '..directory..' | wc -l'))

    -- set the classname to the folder name
    local classname = paths.basename(directory)
    print('packing '..directory..' into '..classname)

    local package = torch.Tensor(packsize, 3, imsize, imsize)
    local i = 0
    for name in paths.iterfiles(directory) do
        local ok, im = pcall(image.load, pathcat(directory, name))
        if ok then
            i = i + 1
            xlua.progress(i,N)
            local ii = 1 + (i-1) % packsize  -- index in a package
            package[ii] = image.scale(im, imsize, imsize)

            local pidx = math.ceil(i/packsize)  -- package index
            if i % packsize == 0 then
                -- save packages have packsize files
                torch.save('./package/'..classname..'_'..pidx..'.t7', package)
            elseif i==N then
                -- save the last package that has < packsize files
                local lastN = N % packsize  -- # of files in the last package
                package = package[{ {1,lastN} }]
                torch.save('./package/'..classname..'_'..pidx..'.t7', package)
            end
        else
            print('==> [ERROR] '..name..' cannot be loaded!')
        end
    end
end

return M
