class PyClass:
    def __init__(self, name: str):
        self.name = name

    def greet(self):
        return f"Hello, {self.name}!"

    def has(self, attr: str) -> bool:
        return hasattr(self, attr)
