"""Exception classes for BitFlow SDK."""


class BitFlowError(Exception):
    """Base exception for BitFlow SDK."""
    
    def __init__(self, message: str, code: str = None, status_code: int = None):
        super().__init__(message)
        self.message = message
        self.code = code
        self.status_code = status_code


class AuthenticationError(BitFlowError):
    """Authentication failed."""
    
    def __init__(self, message: str = "Authentication failed"):
        super().__init__(message, "AUTHENTICATION_ERROR", 401)


class ValidationError(BitFlowError):
    """Request validation failed."""
    
    def __init__(self, message: str):
        super().__init__(message, "VALIDATION_ERROR", 400)


class NotFoundError(BitFlowError):
    """Resource not found."""
    
    def __init__(self, message: str = "Resource not found"):
        super().__init__(message, "NOT_FOUND", 404)


class RateLimitError(BitFlowError):
    """Rate limit exceeded."""
    
    def __init__(self, message: str = "Rate limit exceeded", retry_after: int = None):
        super().__init__(message, "RATE_LIMIT_EXCEEDED", 429)
        self.retry_after = retry_after


class NetworkError(BitFlowError):
    """Network request failed."""
    
    def __init__(self, message: str = "Network request failed"):
        super().__init__(message, "NETWORK_ERROR")