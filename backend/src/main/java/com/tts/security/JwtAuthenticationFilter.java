package com.tts.security;

/*
 * HTTP request filter validating JWT tokens and setting
 * Spring Security context for authenticated users.
 */
import com.tts.repository.UserRepository;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.lang.NonNull;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;

@Component
@RequiredArgsConstructor
public class JwtAuthenticationFilter extends OncePerRequestFilter {

    private final JwtService jwtService;
    private final UserRepository userRepository;

    @Override
    protected void doFilterInternal(
            @NonNull HttpServletRequest request,
            @NonNull HttpServletResponse response,
            @NonNull FilterChain filterChain
    ) throws ServletException, IOException {
        String path = request.getServletPath();
        if (path.equals("/api/auth/login") || path.equals("/api/auth/register") || path.equals("/api/contact") || path.startsWith("/ws/")) {
            filterChain.doFilter(request, response);
            return;
        }
        final String authHeader = request.getHeader("Authorization");
        final String jwt;
        final String username;
        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            filterChain.doFilter(request, response);
            return;
        }
        jwt = authHeader.substring(7);
        try {
            username = jwtService.extractUsername(jwt);
        } catch (Exception e) {
            response.sendError(HttpServletResponse.SC_UNAUTHORIZED, "Invalid token");
            return;
        }

        if (username != null && SecurityContextHolder.getContext().getAuthentication() == null) {
            // Fetch only session version and plan type using projection
            com.tts.repository.UserSessionProjection userProj = userRepository.findSessionAndPlanByUsername(username).orElse(null);
            Long tokenSessionVersion = jwtService.extractSessionVersion(jwt);

            if (userProj != null && tokenSessionVersion != null) {
                if (tokenSessionVersion.longValue() != userProj.getSessionVersion().longValue()) {
                    response.setHeader("X-Logout-Reason", "MULTI_LOGIN");
                    response.sendError(HttpServletResponse.SC_UNAUTHORIZED, "Multiple logins detected");
                    return;
                }
            }

            UserDetails userDetails = org.springframework.security.core.userdetails.User.builder()
                    .username(username)
                    .password("") // Empty password as we don't need it for JWT auth
                    .roles("USER")
                    .build();

            if (userProj != null && jwtService.isTokenValid(jwt, userDetails)) {
                UsernamePasswordAuthenticationToken authToken = new UsernamePasswordAuthenticationToken(
                        userDetails,
                        null,
                        userDetails.getAuthorities()
                );
                authToken.setDetails(
                        new WebAuthenticationDetailsSource().buildDetails(request)
                );
                SecurityContextHolder.getContext().setAuthentication(authToken);

                // Pass access flag to request attributes to avoid DB hit in controllers
                request.setAttribute("planType", userProj.getPlanType());
                request.setAttribute("subscriptionStatus", userProj.getSubscriptionStatus());
                request.setAttribute("planExpiry", userProj.getPlanExpiry());
                request.setAttribute("userId", userProj.getId());
            }
        }
        filterChain.doFilter(request, response);
    }
}
