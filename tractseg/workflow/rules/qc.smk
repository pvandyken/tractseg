rule qc_get_tract_boundaries:
    input:
        rules.transform_to_sample_space.output,
    output:
        temp(work/f"qc_get_tract_boundaries/{uid}.nii.gz")
    group:
        "subj"
    container:
        config["singularity"]["itksnap"]
    shell:
        "c4d {input} -canny 0.5mm 0.5 0.6 {output}"