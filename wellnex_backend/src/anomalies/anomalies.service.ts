import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class AnomaliesService {
  constructor(private readonly prisma: PrismaService) {}

  async createAnomaly(
    userId: string,
    type: string,
    severity: string,
    description: string,
    metadata?: any,
  ) {
    return this.prisma.anomaly.create({
      data: {
        userId,
        type,
        severity,
        description,
        metadata: metadata || {},
      },
    });
  }

  async getAnomalies(page: number, limit: number, status?: string) {
    const skip = (page - 1) * limit;

    const where = status ? { status: status as any } : {};

    const [anomalies, total] = await Promise.all([
      this.prisma.anomaly.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip,
        take: limit,
        include: {
          user: {
            select: { id: true, name: true, email: true, phone: true },
          },
        },
      }),
      this.prisma.anomaly.count({ where }),
    ]);

    return {
      data: anomalies,
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
      },
    };
  }

  async updateStatus(id: string, status: 'PENDING' | 'RESOLVED' | 'IGNORED') {
    const anomaly = await this.prisma.anomaly.findUnique({ where: { id } });
    if (!anomaly) {
      throw new NotFoundException('Anomaly not found');
    }

    return this.prisma.anomaly.update({
      where: { id },
      data: { status },
    });
  }
}
