"""add_user_language

Revision ID: 40be74e99bbb
Revises: 1f6b36f6a82b
Create Date: 2026-02-25 10:16:52.411168

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "40be74e99bbb"
down_revision: Union[str, Sequence[str], None] = "1f6b36f6a82b"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    # ✅ 1) Agregar language a users (esto SÍ funciona en SQLite)
    op.add_column("users", sa.Column("language", sa.String(length=2), nullable=True))

    # ❌ 2) NO cambiar el tipo de status en SQLite (rompe con ALTER COLUMN TYPE)
    bind = op.get_bind()
    if bind.dialect.name != "sqlite":
        with op.batch_alter_table("user_verifications", schema=None) as batch_op:
            batch_op.alter_column(
                "status",
                existing_type=sa.VARCHAR(length=20),
                type_=sa.String(length=50),
                existing_nullable=False,
            )


def downgrade() -> None:
    """Downgrade schema."""
    # revertir language
    op.drop_column("users", "language")

    # revertir type change solo si NO es sqlite
    bind = op.get_bind()
    if bind.dialect.name != "sqlite":
        with op.batch_alter_table("user_verifications", schema=None) as batch_op:
            batch_op.alter_column(
                "status",
                existing_type=sa.String(length=50),
                type_=sa.VARCHAR(length=20),
                existing_nullable=False,
            )