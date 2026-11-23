{% macro apply_pii_masking() %}

    {% if execute %}
        {% for col_name, col in model.columns.items() %}
            {% if col.meta.get('pii') %}
                {% set mask_sql %}
                    ALTER TABLE {{ this }}
                    MODIFY COLUMN {{ col_name }}
                    SET MASKING POLICY {{ target.database }}.governance.mask_pii_string FORCE
                {% endset %}
                {% do run_query(mask_sql) %}

                {% set tag_sql %}
                    ALTER TABLE {{ this }}
                    MODIFY COLUMN {{ col_name }}
                    SET TAG {{ target.database }}.governance.data_classification = 'PII'
                {% endset %}
                {% do run_query(tag_sql) %}

                {{ log("Masked and tagged " ~ col_name ~ " on " ~ this, info=True) }}
            {% endif %}
        {% endfor %}
    {% endif %}

{% endmacro %}
