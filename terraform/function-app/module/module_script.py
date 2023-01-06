import datetime


def date():
    utc_timestamp = datetime.datetime.utcnow()

    return utc_timestamp

print(date())