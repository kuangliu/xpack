# xpack
Yet another data loading module for Torch.  
We adopt the [MXNet](https://mxnet.readthedocs.io/en/latest/system/note_data_loading.html)
data loading philosophy which packs raw images into big packages which can still be loaded into memory one by one.
And instead of loading raw images, loading bigger continuous packages should be more efficient.
