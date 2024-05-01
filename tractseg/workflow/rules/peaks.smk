rule get_response_func:
    input:
        dwi=rules.apply_transform.output["dwi"],
        mask=rules.apply_transform.output["mask"],
    output:
        response=bids(
            out,
            datatype="dwi",
            label="wm",
            model="csd",
            desc="response",
            suffix="fod.txt",
            **inputs["dwi"].wildcards,
        ),
        voxels=bids(
            out,
            datatype="dwi",
            label="wm",
            model="csd",
            suffix="voxels.nii.gz",
            **inputs["dwi"].wildcards,
        ),
    log:
        bids(
            root="code/logs",
            suffix="get_response_func.txt",
            **inputs["dwi"].wildcards,
        ),
    group:
        "subj"
    threads: 4
    resources:
        runtime=10,
    shell:
        """
        dwi2response tournier \\
            {input.dwi} -mask {input.mask} \\
            -voxels {output.voxels} {output.response} \\
            -nthreads {threads} &> {log}
        """

rule compute_csd_fods:
    input:
        dwi=rules.apply_transform.output["dwi"],
        mask=rules.apply_transform.output["mask"],
        response=rules.get_response_func.output["response"]
    output:
        bids(
            out,
            datatype="dwi",
            label="wm",
            model="csd",
            suffix="fod.nii.gz",
            **inputs["dwi"].wildcards,
        )
    log:
        bids(
            root="code/logs",
            suffix="compute_csd_fods.txt",
            **inputs["dwi"].wildcards,
        ),
    group:
        "subj"
    threads: 4
    resources:
        runtime=5
    shell:
        """
        dwi2fod csd {input.dwi} {input.response} -mask {input.mask} {output} \\
            -nthreads {threads} &> {log}
        """

rule compute_peaks:
    input:
        fod=rules.compute_csd_fods.output,
        mask=rules.apply_transform.output["mask"],
    output:
        bids(
            out,
            datatype="dwi",
            label="wm",
            model="csd",
            suffix="peaks.nii.gz",
            **inputs["dwi"].wildcards,
        )
    log:
        bids(
            root="code/logs",
            suffix="compute_peaks.txt",
            **inputs["dwi"].wildcards,
        ),
    group:
        "subj"
    threads: 4
    resources:
        runtime=10,
    shell:
        """
        sh2peaks {input.fod} -mask {input.mask} {output} \\
            -nthreads {threads} &> {log}
        """

        