----------------------------------------------------------------------------
-- This module packs individual images into big continuous packages for
-- fast data accessing. Only image resizing is performed.
----------------------------------------------------------------------------

require 'xlua'
require 'image'
local argcheck = require 'argcheck'

local M = {}
local pathcat = paths.concat

torch.setdefaulttensortype('torch.FloatTensor')

------------------------------------------------------------------
-- pack images organized in subfolders, the subfolder name is the
-- class name.
--
function M.pack(opt)
    local check = argcheck{
        {name='directory', type='string', help='directory containing image folders'},
        {name='imsize', type='number', help='image target size'},
        {name='packsize', type='number', help='# of images per package', default=10000}
    }
    local directory, imsize, packsize = check(opt)

    -- list all subfolders/classes
    local folders = sys.execute('ls -d '..directory..'*/')
    local classes = string.split(folders, '\n') -- split string to table

    -- loop each subfolder to collect images
    local listfile = os.tmpname()
    for i,class in pairs(classes) do
        print('==> parsing '..class)
        -- collect image path to pathfile
        local pathfile = os.tmpname()
        os.execute('ls '..class..'*.jpg > '..pathfile)
        -- attach class to the end of each path
        local outfile = os.tmpname()
        os.execute('awk \'{print $0, "'..i..'"}\' '..pathfile..' > '..outfile)
        -- cat to build a big list file
        os.execute('cat '..outfile..' >> '..listfile)
    end

    M.packlist{
        directory='',  -- as list contains complete path, so directory is empty
        list=listfile,
        imsize=imsize,
        packsize=packsize
    }
end

------------------------------------------------------------------
-- pack images based on a list file, containing image path and
-- targets separated by spaces.
--
function M.packlist(opt)
    local check = argcheck{
        {name='directory', type='string', help='image root directory'},
        {name='list', type='string', help='list file'},
        {name='imsize', type='number', help='image target size'},
        {name='packsize', type='number', help='# of images per package', default=10000}
    }
    local directory, list, imsize, packsize = check(opt)

    -- shuffle list file
    print('==> shuffing list..')
    local shuffled = os.tmpname()
    sys.execute('shuf '..list..' > '..shuffled)
    local N = tonumber(sys.execute('wc -l < '..shuffled))

    -- parse name & targets line by line
    print('==> packing..')
    paths.mkdir('package')
    local images = torch.Tensor(packsize, 3, imsize, imsize)
    local targets

    local f = assert(io.open(shuffled, 'r'))
    local i = 0
    while true do
        local line = f:read('*l')
        if not line then break end

        local splited = string.split(line, '%s+')
        local ok, im = pcall(image.load, pathcat(directory, splited[1]))
        if ok then
            i = i + 1
            xlua.progress(i,N)

            -- pack images
            local ii = 1 + (i-1) % packsize  -- index within a package
            images[ii] = image.scale(im, imsize, imsize)

            -- pack targets
            local target = {}
            for i = 2,#splited do
                target[#target+1] = tonumber(splited[i])
            end
            targets = targets or torch.Tensor(packsize, #target)
            targets[ii] = torch.Tensor(target)

            if i % packsize == 0 then
                -- save packages have packsize files
                pidx = (pidx or 0) + 1  -- package index
                local package = { X = images, Y = targets }
                torch.save('./package/pkg_'..pidx..'.t7', package)
            elseif i==N then
                -- save the last package that has < packsize files
                local lastN = N % packsize  -- # of files in the last package
                images = images[{ {1,lastN} }]
                targets = targets[{ {1,lastN} }]

                pidx = (pidx or 0) + 1
                local package = { X = images, Y = targets }
                torch.save('./package/pkg_'..pidx..'.t7', package)
            end
        end
    end
    f:close()
    print('\n==> '..i..' files packed, '..(N-i)..' files ommited.')
end

return M
