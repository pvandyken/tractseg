from pathlib import Path
import tempfile
from snakebids import bids, generate_inputs, get_wildcard_constraints, set_bids_spec
from bids.layout import Query
import templateflow.api as tflow

set_bids_spec("v0_11_0")

derivatives = config.get("derivatives", None)
# Get input wildcards
inputs = generate_inputs(
    bids_dir=config["bids_dir"],
    pybids_inputs=config["pybids_inputs"],
    pybidsdb_dir=config.get("pybidsdb_dir"),
    pybidsdb_reset=config.get("pybidsdb_reset"),
    derivatives=True if derivatives == [] else derivatives,
    participant_label=config.get("participant_label", None),
    exclude_participant_label=config.get("exclude_participant_label", None),
    validate=not config.get("plugins.validator.skip", False)
)

out = Path(config["output_dir"])
uid = Path(bids(**inputs["dwi"].wildcards)).name
work = Path(os.environ.get("SLURM_TMPDIR", tempfile.mkdtemp(prefix="snakeanat.")))

mni_template = tflow.get(
    template="MNI152NLin6Asym",
    resolution=5,
    suffix="T1w",
    desc=Query.NONE,
    extension=".nii.gz"
)
