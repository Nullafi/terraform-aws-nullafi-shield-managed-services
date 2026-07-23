# ------------------------------------------------------------------------------
# EFS module – file system and mount targets for ECS or other workloads
# ------------------------------------------------------------------------------

resource "aws_efs_file_system" "main" {
  creation_token = var.name_prefix
  encrypted      = var.encrypted

  tags = merge(var.tags, {
    Name = var.name_prefix
  })
}

resource "aws_efs_mount_target" "main" {
  count = length(var.subnet_ids)

  file_system_id  = aws_efs_file_system.main.id
  subnet_id       = var.subnet_ids[count.index]
  security_groups = var.security_group_ids
}

resource "aws_efs_access_point" "main" {
  count = var.access_point_path != null ? 1 : 0

  file_system_id = aws_efs_file_system.main.id
  posix_user {
    gid = var.access_point_posix_gid
    uid = var.access_point_posix_uid
  }
  root_directory {
    path = var.access_point_path
    creation_info {
      owner_gid   = var.access_point_posix_gid
      owner_uid   = var.access_point_posix_uid
      permissions = var.access_point_permissions
    }
  }
}
