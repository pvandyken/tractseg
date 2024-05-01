import nibabel as nb
import numpy as np
import pandas as pd

def do_sampling(param, segmentation, output):
    mask = np.moveaxis(nb.load(segmentation).get_fdata().astype(bool), -1, 0)
    data = nb.load(param).get_fdata()
    result = np.empty((mask.shape[0],))
    for i in range(mask.shape[-1]):
        result[i] = np.mean(data[mask[i]])
    np.savetxt(output, result)


if __name__ == "__main__":
    do_sampling(
        param=snakemake.input.param,  # noqa: F821
        segmentation=snakemake.input.segmentation,  # noqa: F821
        output=snakemake.output[0]
    )
