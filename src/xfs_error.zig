pub const xfs_error = error{
    no_device,
    sb_magic,
    sb_version,
    agf_magic,
    agi_magic,
    no_0_start_offset,
    btree_block_magic,
    xfs_ext_unwritten,
    xfs_ext_zeroed,
    xfs_ext_beyond_sb,
};
