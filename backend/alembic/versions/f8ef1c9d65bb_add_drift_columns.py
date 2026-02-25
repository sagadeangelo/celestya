"""add_drift_columns

Revision ID: f8ef1c9d65bb
Revises: df6f4f2f30c5
Create Date: 2026-02-20 14:42:17.820603

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'f8ef1c9d65bb'
down_revision: Union[str, Sequence[str], None] = 'df6f4f2f30c5'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    conn = op.get_bind()
    inspector = sa.inspect(conn)
    
    # 1. Ensure columns in 'reports'
    if "reports" in inspector.get_table_names():
        existing_reports = [c['name'] for c in inspector.get_columns("reports")]
        if "reporter_id" not in existing_reports:
            # Note: SQLite doesn't support adding FKs to existing tables easily, 
            # but standard op.add_column relative to FK usually works for simple additions.
            op.add_column("reports", sa.Column("reporter_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=True))
            # If it was meant to be nullable=False, we might need a default or data migration.
            # Keeping it nullable=True for safety during migration, then app logic handles it.

    # 2. Ensure columns in 'users'
    if "users" in inspector.get_table_names():
        user_cols = [c['name'] for c in inspector.get_columns("users")]
        with op.batch_alter_table("users") as batch_op:
            # Critical Auth/Verification
            if "email_verified" not in user_cols:
                batch_op.add_column(sa.Column("email_verified", sa.Boolean(), server_default='0', nullable=False))
            if "email_verification_token_hash" not in user_cols:
                batch_op.add_column(sa.Column("email_verification_token_hash", sa.String(255), nullable=True))
            if "last_seen" not in user_cols:
                batch_op.add_column(sa.Column("last_seen", sa.DateTime(timezone=True), nullable=True))
            
            # Profile Fields
            if "gender" not in user_cols:
                batch_op.add_column(sa.Column("gender", sa.String(50), nullable=True))
            if "show_me" not in user_cols:
                batch_op.add_column(sa.Column("show_me", sa.String(50), nullable=True))
            if "city" not in user_cols:
                batch_op.add_column(sa.Column("city", sa.String(255), nullable=True))
            
            # Media
            if "profile_photo_key" not in user_cols:
                batch_op.add_column(sa.Column("profile_photo_key", sa.String(255), nullable=True))
            if "gallery_photo_keys" not in user_cols:
                batch_op.add_column(sa.Column("gallery_photo_keys", sa.JSON(), server_default='[]', nullable=False))
            if "interests" not in user_cols:
                batch_op.add_column(sa.Column("interests", sa.JSON(), server_default='[]', nullable=False))

            # Timestamps if missing
            if "updated_at" not in user_cols:
                batch_op.add_column(sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False))

def downgrade() -> None:
    """Downgrade schema."""
    # Downgrades are optional but good for local dev
    pass
