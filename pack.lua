----------------------------------------------------------------------------
-- This module packs individual image files into a continuous package, for
-- fast data loading.
-- The packages are named as "classname_idx.pac".
----------------------------------------------------------------------------

require 'xlua'
require 'image'

local M = {}
local pathcat = paths.concat

---------------------------------------------------
-- packs the images under the given directory.
--  - directory: containing all the images
--  - imsize: image target size
--
function M.pack(directory, imsize)
    -- classname is the folder name
    local classname = paths.basename(directory)
    print('packing '..directory..' into '..classname)

    local N = sys.fexecute('ls '..directory..' | wc -l')
    local maxnum = 90  -- at most maxnum files per package
    local lastN = N % maxnum    -- # in the last package

    local package = torch.Tensor(maxnum, 3, imsize, imsize)
    local i = 0
    for name in paths.iterfiles(directory) do
        ok, im = pcall(image.load, pathcat(directory, name))
        if ok then
            i = i + 1
            xlua.progress(i,N)
            local ii = 1 + (i-1)%maxnum  -- index in a package
            package[ii] = image.scale(im, imsize, imsize)
        end

        local pidx = math.ceil(i/maxnum)  -- package index
        if i % maxnum == 0 then
            torch.save('./'..classname..'_'..pidx..'.t7', package)
        elseif i == N then
            package = package[{{1,lastN}}]
            torch.save('./'..classname..'_'..pidx..'.t7', package)
        end
    end
end

return M
