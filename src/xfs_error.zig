pub const xfs_error = error{
    sb_magic,
    sb_version,
    agf_magic,
    agi_magic,
    no_0_start_offset,
    btree_block_magic,
};
