FROM astrocrpublic.azurecr.io/runtime:3.3-12

RUN pip install --no-cache-dir \
    astronomer-cosmos==1.8.3 \
    dbt-core==1.8.8 \
    dbt-snowflake==1.8.4 \
    apache-airflow-providers-snowflake==6.4.0