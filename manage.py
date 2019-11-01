from flask.cli import FlaskGroup
from project import app, db


# we created a new FlaskGroup instance to extend the normal CLI with commands related to the Flask app.
cli = FlaskGroup(app)


@cli.command('recreate_db')
def recreate_db():
    db.drop_all()
    db.create_all()
    db.session.commit()


if __name__ == '__main__':
    cli()
