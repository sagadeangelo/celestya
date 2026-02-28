"""add voice_intro_key to users

Revision ID: 0fbcdb5520db
Revises: 40be74e99bbb
Create Date: 2026-02-28 10:42:04.470125

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '0fbcdb5520db'
down_revision: Union[str, Sequence[str], None] = '40be74e99bbb'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    with op.batch_alter_table("users", schema=None) as batch_op:
        batch_op.add_column(sa.Column("voice_intro_key", sa.String(length=255), nullable=True))
        batch_op.create_index(batch_op.f("ix_users_voice_intro_key"), ["voice_intro_key"], unique=False)


def downgrade() -> None:
    """Downgrade schema."""
    with op.batch_alter_table("users", schema=None) as batch_op:
        batch_op.drop_index(batch_op.f("ix_users_voice_intro_key"))
        batch_op.drop_column("voice_intro_key")
