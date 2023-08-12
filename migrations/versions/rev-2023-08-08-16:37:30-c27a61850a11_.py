"""empty message

Revision ID: c27a61850a11
Revises: 7e91153d66b0
Create Date: 2023-08-07 11:37:30.000148

"""

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'c27a61850a11'
down_revision = '7e91153d66b0'


def upgrade():
    # ### commands auto generated by Alembic - please adjust! ###
    op.add_column('video_streams', sa.Column('is_chat_enabled', sa.Boolean(), nullable=True))
    op.add_column('video_streams', sa.Column('is_global_event_room', sa.Boolean(), nullable=True))
    op.add_column('video_streams', sa.Column('chat_room_id', sa.String(), nullable=True))
    # ### end Alembic commands ###


def downgrade():
    # ### commands auto generated by Alembic - please adjust! ###
    op.drop_column('video_streams', 'chat_room_id')
    op.drop_column('video_streams', 'is_global_event_room')
    op.drop_column('video_streams', 'is_chat_enabled')
    # ### end Alembic commands ###