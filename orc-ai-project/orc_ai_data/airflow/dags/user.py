from airflow.sdk import asset
import requests

@asset(
    schedule='@daily',
    uri='https://randomuser.me/api/'
)
def user(uri: str) -> dict[str]:
    r = requests.get(uri)
    return r.json()