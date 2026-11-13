from airflow import DAG
from airflow.operators.bash import BashOperator
from cosmos import DbtTaskGroup, ProjectConfig, ProfileConfig
from cosmos.profiles import SnowflakeUserPasswordProfileMapping
from datetime import datetime, timedelta
from cosmos import RenderConfig

profile_config = ProfileConfig(
    profile_name="avenoirel",
    target_name="dev",
    profile_mapping=SnowflakeUserPasswordProfileMapping(
        conn_id="snowflake_default",
    ),
)

default_args = {
    'retries': 3,
    'retry_delay': timedelta(minutes=5),
}

with DAG(
    dag_id="ops_bookings_hourly",
    schedule="0 * * * *",
    start_date=datetime(2025, 1, 1),
    catchup=False,
    default_args=default_args,
    tags=["owner:sachin", "domain:operations", "criticality:high"],
) as dag:

    source_freshness = BashOperator(
        task_id="dbt_source_freshness",
        retries=0,
        bash_command="dbt source freshness --project-dir /usr/local/airflow/dags/dbt --profiles-dir /usr/local/airflow/dags/dbt",
    )

    dbt_operations = DbtTaskGroup(
        group_id="operations_models",
        project_config=ProjectConfig(dbt_project_path="/usr/local/airflow/dags/dbt"),
        profile_config=profile_config,
        render_config=RenderConfig(select=["tag:operations"]),
    )

    source_freshness >> dbt_operations