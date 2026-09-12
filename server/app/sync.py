from fastapi import HTTPException

def ensure_new_operation(cur, operation_id, user_id, operation_type):
    """
    Returns True if operation can continue.
    If the same operation UUID was already committed, raises 409.
    """
    if not operation_id:
        return True

    cur.execute(
        "select 1 from client_operations where operation_id = %s",
        (operation_id,),
    )
    if cur.fetchone():
        raise HTTPException(
            status_code=409,
            detail={
                "code": "operation_already_processed",
                "message": "Bu işlem daha önce başarıyla işlendi.",
            },
        )

    cur.execute(
        """
        insert into client_operations(operation_id, user_id, operation_type)
        values (%s, %s, %s)
        """,
        (operation_id, user_id, operation_type),
    )
    return True

def emit_sync_event(cur, entity_type, entity_id, action, payload=None):
    cur.execute(
        """
        insert into sync_events(entity_type, entity_id, action, payload)
        values (%s, %s, %s, %s)
        returning seq
        """,
        (entity_type, str(entity_id), action, payload),
    )
    return cur.fetchone()["seq"]
