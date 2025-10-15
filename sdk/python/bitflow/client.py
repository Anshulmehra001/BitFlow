"""BitFlow API client."""

import json
from typing import Dict, List, Optional, Union
from urllib.parse import urlencode

import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

from .types import (
    Stream,
    CreateStreamRequest,
    StreamsResponse,
    StreamFilters,
    Subscription,
    SubscriptionPlan,
    CreateSubscriptionPlanRequest,
    CreateSubscriptionRequest,
    WebhookEndpoint,
    CreateWebhookRequest,
    ApiResponse,
)
from .exceptions import (
    BitFlowError,
    AuthenticationError,
    ValidationError,
    NotFoundError,
    RateLimitError,
    NetworkError,
)


class BitFlowClient:
    """BitFlow API client for Python."""

    def __init__(
        self,
        api_key: str,
        base_url: str = "https://api.bitflow.dev",
        timeout: int = 30,
        max_retries: int = 3,
    ):
        """Initialize BitFlow client.
        
        Args:
            api_key: Your BitFlow API key
            base_url: API base URL (default: https://api.bitflow.dev)
            timeout: Request timeout in seconds (default: 30)
            max_retries: Maximum number of retries (default: 3)
        """
        self.api_key = api_key
        self.base_url = base_url.rstrip("/")
        self.timeout = timeout

        # Configure session with retries
        self.session = requests.Session()
        retry_strategy = Retry(
            total=max_retries,
            backoff_factor=1,
            status_forcelist=[429, 500, 502, 503, 504],
        )
        adapter = HTTPAdapter(max_retries=retry_strategy)
        self.session.mount("http://", adapter)
        self.session.mount("https://", adapter)

        # Set default headers
        self.session.headers.update({
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
            "User-Agent": "BitFlow-SDK-Python/1.0.0",
        })

    def _request(
        self,
        method: str,
        endpoint: str,
        data: Optional[Dict] = None,
        params: Optional[Dict] = None,
    ) -> Dict:
        """Make HTTP request to API."""
        url = f"{self.base_url}{endpoint}"
        
        try:
            response = self.session.request(
                method=method,
                url=url,
                json=data,
                params=params,
                timeout=self.timeout,
            )
            
            # Handle different response status codes
            if response.status_code == 401:
                raise AuthenticationError("Invalid API key")
            elif response.status_code == 400:
                error_data = response.json().get("error", {})
                raise ValidationError(error_data.get("message", "Bad request"))
            elif response.status_code == 404:
                error_data = response.json().get("error", {})
                raise NotFoundError(error_data.get("message", "Not found"))
            elif response.status_code == 429:
                retry_after = response.headers.get("Retry-After")
                raise RateLimitError(
                    "Rate limit exceeded",
                    retry_after=int(retry_after) if retry_after else None
                )
            elif response.status_code >= 400:
                error_data = response.json().get("error", {})
                raise BitFlowError(
                    error_data.get("message", "API request failed"),
                    error_data.get("code"),
                    response.status_code
                )
            
            return response.json()
            
        except requests.exceptions.RequestException as e:
            raise NetworkError(f"Network request failed: {str(e)}")

    # Stream Management
    def create_stream(self, request: CreateStreamRequest) -> Stream:
        """Create a new payment stream."""
        data = {
            "recipient": request.recipient,
            "amount": request.amount,
            "rate": request.rate,
            "duration": request.duration,
        }
        
        response = self._request("POST", "/api/streams", data=data)
        stream_data = response["data"]["stream"]
        
        return Stream(
            id=stream_data["id"],
            sender=stream_data["sender"],
            recipient=stream_data["recipient"],
            total_amount=stream_data["totalAmount"],
            rate_per_second=stream_data["ratePerSecond"],
            start_time=stream_data["startTime"],
            end_time=stream_data["endTime"],
            withdrawn_amount=stream_data["withdrawnAmount"],
            is_active=stream_data["isActive"],
        )

    def get_streams(self, filters: Optional[StreamFilters] = None) -> StreamsResponse:
        """Get user's streams."""
        params = {}
        if filters:
            if filters.status:
                params["status"] = filters.status.value
            if filters.limit:
                params["limit"] = filters.limit
            if filters.offset:
                params["offset"] = filters.offset

        response = self._request("GET", "/api/streams", params=params)
        
        streams = [
            Stream(
                id=s["id"],
                sender=s["sender"],
                recipient=s["recipient"],
                total_amount=s["totalAmount"],
                rate_per_second=s["ratePerSecond"],
                start_time=s["startTime"],
                end_time=s["endTime"],
                withdrawn_amount=s["withdrawnAmount"],
                is_active=s["isActive"],
            )
            for s in response["streams"]
        ]
        
        return StreamsResponse(
            streams=streams,
            pagination=response["pagination"]
        )

    def get_stream(self, stream_id: str) -> Stream:
        """Get stream details."""
        response = self._request("GET", f"/api/streams/{stream_id}")
        stream_data = response["data"]["stream"]
        
        return Stream(
            id=stream_data["id"],
            sender=stream_data["sender"],
            recipient=stream_data["recipient"],
            total_amount=stream_data["totalAmount"],
            rate_per_second=stream_data["ratePerSecond"],
            start_time=stream_data["startTime"],
            end_time=stream_data["endTime"],
            withdrawn_amount=stream_data["withdrawnAmount"],
            is_active=stream_data["isActive"],
        )

    def cancel_stream(self, stream_id: str) -> None:
        """Cancel a payment stream."""
        self._request("POST", f"/api/streams/{stream_id}/cancel")

    def withdraw_from_stream(self, stream_id: str) -> str:
        """Withdraw from a payment stream."""
        response = self._request("POST", f"/api/streams/{stream_id}/withdraw")
        return response["data"]["withdrawnAmount"]

    # Subscription Management
    def create_subscription_plan(self, request: CreateSubscriptionPlanRequest) -> SubscriptionPlan:
        """Create a subscription plan."""
        data = {
            "name": request.name,
            "price": request.price,
            "interval": request.interval,
        }
        if request.description:
            data["description"] = request.description
        if request.max_subscribers:
            data["maxSubscribers"] = request.max_subscribers

        response = self._request("POST", "/api/subscriptions/plans", data=data)
        plan_data = response["data"]["plan"]
        
        return SubscriptionPlan(
            id=plan_data["id"],
            provider=plan_data["provider"],
            name=plan_data["name"],
            description=plan_data.get("description"),
            price=plan_data["price"],
            interval=plan_data["interval"],
            max_subscribers=plan_data["maxSubscribers"],
        )

    def get_subscription_plans(self, provider: Optional[str] = None) -> List[SubscriptionPlan]:
        """Get subscription plans."""
        params = {}
        if provider:
            params["provider"] = provider

        response = self._request("GET", "/api/subscriptions/plans", params=params)
        
        return [
            SubscriptionPlan(
                id=p["id"],
                provider=p["provider"],
                name=p["name"],
                description=p.get("description"),
                price=p["price"],
                interval=p["interval"],
                max_subscribers=p["maxSubscribers"],
            )
            for p in response["data"]["plans"]
        ]

    def subscribe(self, request: CreateSubscriptionRequest) -> str:
        """Subscribe to a plan."""
        data = {
            "planId": request.plan_id,
            "duration": request.duration,
        }
        if request.auto_renew is not None:
            data["autoRenew"] = request.auto_renew

        response = self._request("POST", "/api/subscriptions", data=data)
        return response["data"]["subscriptionId"]

    def get_subscriptions(self) -> List[Subscription]:
        """Get user's subscriptions."""
        response = self._request("GET", "/api/subscriptions")
        
        return [
            Subscription(
                id=s["id"],
                plan_id=s["planId"],
                subscriber=s["subscriber"],
                provider=s["provider"],
                stream_id=s["streamId"],
                start_time=s["startTime"],
                end_time=s["endTime"],
                auto_renew=s["autoRenew"],
                status=s["status"],
            )
            for s in response["data"]["subscriptions"]
        ]

    def cancel_subscription(self, subscription_id: str) -> None:
        """Cancel a subscription."""
        self._request("POST", f"/api/subscriptions/{subscription_id}/cancel")

    # Webhook Management
    def create_webhook(self, request: CreateWebhookRequest) -> WebhookEndpoint:
        """Create a webhook endpoint."""
        data = {
            "url": request.url,
            "events": [event.value for event in request.events],
        }
        if request.description:
            data["description"] = request.description

        response = self._request("POST", "/api/webhooks/endpoints", data=data)
        endpoint_data = response["data"]["endpoint"]
        
        return WebhookEndpoint(
            id=endpoint_data["id"],
            url=endpoint_data["url"],
            events=[event for event in endpoint_data["events"]],
            description=endpoint_data.get("description"),
            secret=endpoint_data["secret"],
            is_active=endpoint_data["isActive"],
            created_at=endpoint_data["createdAt"],
        )

    def get_webhooks(self) -> List[WebhookEndpoint]:
        """Get webhook endpoints."""
        response = self._request("GET", "/api/webhooks/endpoints")
        
        return [
            WebhookEndpoint(
                id=e["id"],
                url=e["url"],
                events=e["events"],
                description=e.get("description"),
                secret=e.get("secret", ""),
                is_active=e["isActive"],
                created_at=e["createdAt"],
            )
            for e in response["data"]["endpoints"]
        ]

    def update_webhook(
        self,
        endpoint_id: str,
        url: Optional[str] = None,
        events: Optional[List[str]] = None,
        is_active: Optional[bool] = None,
    ) -> WebhookEndpoint:
        """Update a webhook endpoint."""
        data = {}
        if url:
            data["url"] = url
        if events:
            data["events"] = events
        if is_active is not None:
            data["isActive"] = is_active

        response = self._request("PUT", f"/api/webhooks/endpoints/{endpoint_id}", data=data)
        endpoint_data = response["data"]["endpoint"]
        
        return WebhookEndpoint(
            id=endpoint_data["id"],
            url=endpoint_data["url"],
            events=endpoint_data["events"],
            description=endpoint_data.get("description"),
            secret=endpoint_data.get("secret", ""),
            is_active=endpoint_data["isActive"],
            created_at=endpoint_data["createdAt"],
        )

    def delete_webhook(self, endpoint_id: str) -> None:
        """Delete a webhook endpoint."""
        self._request("DELETE", f"/api/webhooks/endpoints/{endpoint_id}")

    def test_webhook(self, endpoint_id: str) -> Dict:
        """Test a webhook endpoint."""
        data = {"endpointId": endpoint_id}
        response = self._request("POST", "/api/webhooks/test", data=data)
        return response["data"]["result"]