rule run_tractseg:
    input:
        peaks=rules.compute_peaks.output,
        mask=rules.apply_transform.output["mask"]
    output:
        bids(
            out,
            datatype="dwi",
            space="MNI152NLin6Asym",
            atlas="tractseg",
            suffix="dseg.nii.gz",
            **inputs["dwi"].wildcards,
        )
    log:
        bids(
            root="code/logs",
            suffix="run_tractseg.txt",
            **inputs["dwi"].wildcards,
        ),
    container: config["singularity"]["tractseg"]
    threads: 4
    resources:
        runtime=45,
        mem_mb=16000,
    group: "subj"
    shadow: "minimal"
    shell:
        """
        TractSeg -i {input.peaks} -o . \\
            --brain_mask {input.mask} --postprocess --single_output_file \\
            --nr_cpus {threads}
        mv tractseg_output/bundle_segmentations.nii.gz {output}
        """

rule get_original_dwi_ref:
    input: inputs["dwi"].path
    output: temp(work / f"get_original_dwi_ref/{uid}.nii.gz")
    group: "subj"
    shell:
        """
        mrconvert -q {input} {output} -coord 3 0 -axes 0,1,2
        """

rule transform_to_sample_space:
    input:
        seg=rules.run_tractseg.output,
        txf=rules.convert_xfm_ras2itk.output,
        ref=rules.get_original_dwi_ref.output,
    output:
        bids(
            out,
            datatype="dwi",
            atlas="tractseg",
            suffix="dseg.nii.gz",
            **inputs["dwi"].wildcards,
        )
    container: config["singularity"]["ants"]
    group: "subj"
    resources:
        runtime=2,
    shadow: "minimal"
    shell:
        """
        antsApplyTransforms -d 3 -e 3 \\
            -i "{input.seg}" -r "{input.ref}" -t "[{input.txf},1]" \\
            -o "{output}" -n GenericLabel
        """
