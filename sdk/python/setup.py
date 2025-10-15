from setuptools import setup, find_packages

with open("README.md", "r", encoding="utf-8") as fh:
    long_description = fh.read()

setup(
    name="bitflow-sdk",
    version="1.0.0",
    author="BitFlow Team",
    author_email="dev@bitflow.dev",
    description="Official Python SDK for BitFlow payment streaming protocol",
    long_description=long_description,
    long_description_content_type="text/markdown",
    url="https://github.com/bitflow/sdk-python",
    packages=find_packages(),
    classifiers=[
        "Development Status :: 4 - Beta",
        "Intended Audience :: Developers",
        "License :: OSI Approved :: MIT License",
        "Operating System :: OS Independent",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
        "Topic :: Software Development :: Libraries :: Python Modules",
        "Topic :: Internet :: WWW/HTTP",
        "Topic :: Office/Business :: Financial",
    ],
    python_requires=">=3.8",
    install_requires=[
        "requests>=2.28.0",
        "typing-extensions>=4.0.0",
    ],
    extras_require={
        "dev": [
            "pytest>=7.0.0",
            "pytest-asyncio>=0.21.0",
            "black>=22.0.0",
            "flake8>=5.0.0",
            "mypy>=1.0.0",
        ],
        "async": [
            "aiohttp>=3.8.0",
        ],
    },
    keywords="bitcoin payment streaming starknet crypto defi",
    project_urls={
        "Bug Reports": "https://github.com/bitflow/sdk-python/issues",
        "Source": "https://github.com/bitflow/sdk-python",
        "Documentation": "https://docs.bitflow.dev",
    },
)