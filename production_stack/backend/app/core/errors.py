from fastapi import HTTPException, status


class AppError(HTTPException):
    def __init__(self, *, http_status: int, code: int, message: str):
        super().__init__(status_code=http_status, detail={"code": code, "message": message})


class ErrorCode:
    INVALID_PARAMS = 1001
    TOO_MANY_REQUESTS = 1002
    UNAUTHORIZED = 1003
    FORBIDDEN = 1004
    NOT_FOUND = 1005
    CONFLICT = 1006
    INTERNAL_ERROR = 1999


def bad_request(message: str, code: int = ErrorCode.INVALID_PARAMS) -> AppError:
    return AppError(http_status=status.HTTP_400_BAD_REQUEST, code=code, message=message)


def unauthorized(message: str = "未登录或登录已过期") -> AppError:
    return AppError(http_status=status.HTTP_401_UNAUTHORIZED, code=ErrorCode.UNAUTHORIZED, message=message)


def forbidden(message: str = "无权限") -> AppError:
    return AppError(http_status=status.HTTP_403_FORBIDDEN, code=ErrorCode.FORBIDDEN, message=message)


def not_found(message: str = "资源不存在") -> AppError:
    return AppError(http_status=status.HTTP_404_NOT_FOUND, code=ErrorCode.NOT_FOUND, message=message)


def conflict(message: str = "请求冲突") -> AppError:
    return AppError(http_status=status.HTTP_409_CONFLICT, code=ErrorCode.CONFLICT, message=message)


def too_many_requests(message: str = "请求过于频繁，请稍后再试") -> AppError:
    return AppError(http_status=status.HTTP_429_TOO_MANY_REQUESTS, code=ErrorCode.TOO_MANY_REQUESTS, message=message)
