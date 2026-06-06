import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;

public class GatewayConnector {
    private final HttpClient client;
    private final String baseUrl;

    public GatewayConnector(String baseUrl) {
        this.baseUrl = baseUrl;
        this.client = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(5))
            .build();
    }

    public int checkHealth() throws Exception {
        HttpRequest request = HttpRequest.newBuilder()
            .uri(URI.create(baseUrl + "/health"))
            .timeout(Duration.ofSeconds(5))
            .GET().build();
        return client.send(request, HttpResponse.BodyHandlers.ofString()).statusCode();
    }

    public static void main(String[] args) throws Exception {
        String url = args.length > 0 ? args[0] : "http://localhost:8080";
        int status = new GatewayConnector(url).checkHealth();
        System.out.println("Gateway " + url + " -> HTTP " + status);
    }
}