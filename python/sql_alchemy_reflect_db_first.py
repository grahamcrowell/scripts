from sqlalchemy.ext.automap import automap_base
from sqlalchemy.orm import Session
from sqlalchemy import create_engine
import urllib


Base = automap_base()

# engine, suppose it has two tables 'user' and 'address' set up
params = urllib.parse.quote_plus("DRIVER={ODBC Driver 13 for Sql Server};SERVER=localhost;DATABASE=AutoTest;UID=sa;PWD=2and2is5")
params = urllib.parse.quote_plus("DRIVER={ODBC Driver 11 for Sql Server};SERVER=STDBDECSUP01;DATABASE=GenericProfiles;Trusted_Connection=Yes;")
engine = create_engine('mssql+pyodbc:///?odbc_connect='+params)

# reflect the tables
Base.prepare(engine, reflect=True)

# mapped classes are now created with names by default
# matching that of the table name.
print(*Base.classes)
# User = Base.classes.user
# Address = Base.classes.address

# session = Session(engine)

# # rudimentary relationships are produced
# session.add(Address(email_address="foo@bar.com", user=User(name="foo")))
# session.commit()

# # collection-based relationships are by default named
# # "<classname>_collection"
# print (u1.address_collection)