"""Type definitions for BitFlow SDK."""

from typing import Dict, List, Optional, Union, Literal
from dataclasses import dataclass
from enum import Enum


class WebhookEvent(str, Enum):
    """Webhook event types."""
    STREAM_CREATED = "stream.created"
    STREAM_CANCELLED = "stream.cancelled"
    STREAM_COMPLETED = "stream.completed"
    SUBSCRIPTION_CREATED = "subscription.created"
    SUBSCRIPTION_CANCELLED = "subscription.cancelled"
    PAYMENT_RECEIVED = "payment.received"


class StreamStatus(str, Enum):
    """Stream status types."""
    ACTIVE = "active"
    COMPLETED = "completed"
    CANCELLED = "cancelled"


class SubscriptionStatus(str, Enum):
    """Subscription status types."""
    ACTIVE = "active"
    CANCELLED = "cancelled"
    EXPIRED = "expired"


@dataclass
class Stream:
    """Payment stream data."""
    id: str
    sender: str
    recipient: str
    total_amount: str
    rate_per_second: str
    start_time: int
    end_time: int
    withdrawn_amount: str
    is_active: bool


@dataclass
class CreateStreamRequest:
    """Request data for creating a stream."""
    recipient: str
    amount: str
    rate: str
    duration: int


@dataclass
class StreamsResponse:
    """Response data for streams list."""
    streams: List[Stream]
    pagination: Dict[str, int]


@dataclass
class Subscription:
    """Subscription data."""
    id: str
    plan_id: str
    subscriber: str
    provider: str
    stream_id: str
    start_time: int
    end_time: int
    auto_renew: bool
    status: SubscriptionStatus


@dataclass
class SubscriptionPlan:
    """Subscription plan data."""
    id: str
    provider: str
    name: str
    description: Optional[str]
    price: str
    interval: int
    max_subscribers: int


@dataclass
class CreateSubscriptionPlanRequest:
    """Request data for creating a subscription plan."""
    name: str
    description: Optional[str]
    price: str
    interval: int
    max_subscribers: Optional[int] = None


@dataclass
class CreateSubscriptionRequest:
    """Request data for creating a subscription."""
    plan_id: str
    duration: int
    auto_renew: Optional[bool] = False


@dataclass
class WebhookEndpoint:
    """Webhook endpoint data."""
    id: str
    url: str
    events: List[WebhookEvent]
    description: Optional[str]
    secret: str
    is_active: bool
    created_at: str


@dataclass
class CreateWebhookRequest:
    """Request data for creating a webhook."""
    url: str
    events: List[WebhookEvent]
    description: Optional[str] = None


@dataclass
class WebhookPayload:
    """Webhook payload data."""
    id: str
    event: WebhookEvent
    data: Dict
    timestamp: str


@dataclass
class ApiResponse:
    """Generic API response."""
    data: Optional[Dict] = None
    error: Optional[Dict] = None


@dataclass
class PaginationOptions:
    """Pagination options."""
    limit: Optional[int] = None
    offset: Optional[int] = None


@dataclass
class StreamFilters(PaginationOptions):
    """Stream filtering options."""
    status: Optional[StreamStatus] = None